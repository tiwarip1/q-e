!
! Copyright (C) 2003-2009 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
SUBROUTINE vloc_psi_gamma(lda, n, m, psi, v, hpsi)
  !-----------------------------------------------------------------------
  !
  ! Calculation of Vloc*psi using dual-space technique - Gamma point
  !
  USE parallel_include
  USE kinds,   ONLY : DP
  USE gsmooth, ONLY : nls, nlsm, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, nrxxs
  USE wvfct,   ONLY : igk
  USE mp_global,     ONLY : nogrp, ogrp_comm, me_pool, nolist, use_task_groups
  USE fft_parallel,  ONLY : tg_cft3s
  USE fft_base,      ONLY : dffts
  USE task_groups,   ONLY : tg_gather
  USE wavefunctions_module,  ONLY: psic
  !
  IMPLICIT NONE
  !
  INTEGER, INTENT(in) :: lda, n, m
  COMPLEX(DP), INTENT(in)   :: psi (lda, m)
  COMPLEX(DP), INTENT(inout):: hpsi (lda, m)
  REAL(DP), INTENT(in) :: v(nrxxs)
  !
  INTEGER :: ibnd, j, incr
  COMPLEX(DP) :: fp, fm
  !
  LOGICAL :: use_tg
  ! Variables for task groups
  REAL(DP),    ALLOCATABLE :: tg_v(:)
  COMPLEX(DP), ALLOCATABLE :: tg_psic(:)
  INTEGER :: v_siz, idx, ioff
  !
  !
  incr = 2
  !
  use_tg = ( use_task_groups ) .and. ( m >= nogrp )
  !
  IF( use_tg ) THEN
     !
     v_siz =  dffts%nnrx * nogrp
     !
     ALLOCATE( tg_v   ( v_siz ) )
     ALLOCATE( tg_psic( v_siz ) )
     !
     CALL tg_gather( dffts, v, tg_v )
     !
     incr = 2 * nogrp
     !
  ENDIF
  !
  ! the local potential V_Loc psi. First bring psi to real space
  !
  DO ibnd = 1, m, incr
     !
     IF( use_tg ) THEN
        !
        tg_psic = (0.d0, 0.d0)
        ioff   = 0
        !
        DO idx = 1, 2*nogrp, 2
           IF( idx + ibnd - 1 < m ) THEN
              DO j = 1, n
                 tg_psic(nls (igk(j))+ioff) =        psi(j,idx+ibnd-1) + &
                                      (0.0d0,1.d0) * psi(j,idx+ibnd)
                 tg_psic(nlsm(igk(j))+ioff) = conjg( psi(j,idx+ibnd-1) - &
                                      (0.0d0,1.d0) * psi(j,idx+ibnd) )
              ENDDO
           ELSEIF( idx + ibnd - 1 == m ) THEN
              DO j = 1, n
                 tg_psic(nls (igk(j))+ioff) =        psi(j,idx+ibnd-1)
                 tg_psic(nlsm(igk(j))+ioff) = conjg( psi(j,idx+ibnd-1) )
              ENDDO
           ENDIF

           ioff = ioff + dffts%nnrx

        ENDDO
        !
     ELSE
        !
        psic(:) = (0.d0, 0.d0)
        IF (ibnd < m) THEN
           ! two ffts at the same time
           DO j = 1, n
              psic (nls (igk(j))) =       psi(j, ibnd) + (0.0d0,1.d0)*psi(j, ibnd+1)
              psic (nlsm(igk(j))) = conjg(psi(j, ibnd) - (0.0d0,1.d0)*psi(j, ibnd+1))
           ENDDO
        ELSE
           DO j = 1, n
              psic (nls (igk(j))) =       psi(j, ibnd)
              psic (nlsm(igk(j))) = conjg(psi(j, ibnd))
           ENDDO
        ENDIF
        !
     ENDIF
     !
     !   fft to real space
     !   product with the potential v on the smooth grid
     !   back to reciprocal space
     !
     IF( use_tg ) THEN
        !
        CALL tg_cft3s ( tg_psic, dffts, 2, use_tg )
        !
        DO j = 1, nrx1s * nrx2s * dffts%tg_npp( me_pool + 1 )
           tg_psic (j) = tg_psic (j) * tg_v(j)
        ENDDO
        !
        CALL tg_cft3s ( tg_psic, dffts, -2, use_tg )
        !
     ELSE
        !
        CALL cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, 2)
        !
        DO j = 1, nrxxs
           psic (j) = psic (j) * v(j)
        ENDDO
        !
        CALL cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, - 2)
        !
     ENDIF
     !
     !   addition to the total product
     !
     IF( use_tg ) THEN
        !
        ioff   = 0
        !
        DO idx = 1, 2*nogrp, 2
           !
           IF( idx + ibnd - 1 < m ) THEN
              DO j = 1, n
                 fp= ( tg_psic( nls(igk(j)) + ioff ) +  tg_psic( nlsm(igk(j)) + ioff ) ) * 0.5d0
                 fm= ( tg_psic( nls(igk(j)) + ioff ) -  tg_psic( nlsm(igk(j)) + ioff ) ) * 0.5d0
                 hpsi (j, ibnd+idx-1) = hpsi (j, ibnd+idx-1) + cmplx( dble(fp), aimag(fm),kind=DP)
                 hpsi (j, ibnd+idx  ) = hpsi (j, ibnd+idx  ) + cmplx(aimag(fp),- dble(fm),kind=DP)
              ENDDO
           ELSEIF( idx + ibnd - 1 == m ) THEN
              DO j = 1, n
                 hpsi (j, ibnd+idx-1) = hpsi (j, ibnd+idx-1) + tg_psic( nls(igk(j)) + ioff )
              ENDDO
           ENDIF
           !
           ioff = ioff + dffts%nr3x * dffts%nsw( me_pool + 1 )
           !
        ENDDO
        !
     ELSE
        IF (ibnd < m) THEN
           ! two ffts at the same time
           DO j = 1, n
              fp = (psic (nls(igk(j))) + psic (nlsm(igk(j))))*0.5d0
              fm = (psic (nls(igk(j))) - psic (nlsm(igk(j))))*0.5d0
              hpsi (j, ibnd)   = hpsi (j, ibnd)   + cmplx( dble(fp), aimag(fm),kind=DP)
              hpsi (j, ibnd+1) = hpsi (j, ibnd+1) + cmplx(aimag(fp),- dble(fm),kind=DP)
           ENDDO
        ELSE
           DO j = 1, n
              hpsi (j, ibnd)   = hpsi (j, ibnd)   + psic (nls(igk(j)))
           ENDDO
        ENDIF
     ENDIF
     !
  ENDDO
  !
  IF( use_tg ) THEN
     !
     DEALLOCATE( tg_psic )
     DEALLOCATE( tg_v )
     !
  ENDIF
  !
  RETURN
END SUBROUTINE vloc_psi_gamma
!
!-----------------------------------------------------------------------
SUBROUTINE vloc_psi_k(lda, n, m, psi, v, hpsi)
  !-----------------------------------------------------------------------
  !
  ! Calculation of Vloc*psi using dual-space technique - k-points
  !
  USE parallel_include
  USE kinds,   ONLY : DP
  USE gsmooth, ONLY : nls, nlsm, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, nrxxs
  USE wvfct,   ONLY : igk
  USE mp_global,     ONLY : nogrp, ogrp_comm, me_pool, nolist, use_task_groups
  USE fft_parallel,  ONLY : tg_cft3s
  USE fft_base,      ONLY : dffts
  USE task_groups,   ONLY : tg_gather
  USE wavefunctions_module,  ONLY: psic
  !
  IMPLICIT NONE
  !
  INTEGER, INTENT(in) :: lda, n, m
  COMPLEX(DP), INTENT(in)   :: psi (lda, m)
  COMPLEX(DP), INTENT(inout):: hpsi (lda, m)
  REAL(DP), INTENT(in) :: v(nrxxs)
  !
  INTEGER :: ibnd, j, incr
  !
  LOGICAL :: use_tg
  ! Task Groups
  REAL(DP),    ALLOCATABLE :: tg_v(:)
  COMPLEX(DP), ALLOCATABLE :: tg_psic(:)
  INTEGER :: v_siz, idx, ioff
  !
  !
  use_tg = ( use_task_groups ) .and. ( m >= nogrp )
  !
  incr = 1
  !
  IF( use_tg ) THEN
     !
     v_siz =  dffts%nnrx * nogrp
     !
     ALLOCATE( tg_v   ( v_siz ) )
     ALLOCATE( tg_psic( v_siz ) )
     !
     CALL tg_gather( dffts, v, tg_v )
     incr = nogrp
     !
  ENDIF
  !
  ! the local potential V_Loc psi. First bring psi to real space
  !
  DO ibnd = 1, m, incr
     !
     IF( use_tg ) THEN
        !
        tg_psic = (0.d0, 0.d0)
        ioff   = 0
        !
        DO idx = 1, nogrp

           IF( idx + ibnd - 1 <= m ) THEN
!$omp parallel do
              DO j = 1, n
                 tg_psic(nls (igk(j))+ioff) =  psi(j,idx+ibnd-1)
              ENDDO
!$omp end parallel do
           ENDIF

           ioff = ioff + dffts%nnrx

        ENDDO
        !
        CALL tg_cft3s ( tg_psic, dffts, 2, use_tg )
        !
     ELSE
        !
        psic(:) = (0.d0, 0.d0)
        psic (nls (igk(1:n))) = psi(1:n, ibnd)
        !
        CALL cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, 2)
        !
     ENDIF
     !
     !   fft to real space
     !   product with the potential v on the smooth grid
     !   back to reciprocal space
     !
     IF( use_tg ) THEN
        !
!$omp parallel do
        DO j = 1, nrx1s * nrx2s * dffts%tg_npp( me_pool + 1 )
           tg_psic (j) = tg_psic (j) * tg_v(j)
        ENDDO
!$omp end parallel do
        !
        CALL tg_cft3s ( tg_psic, dffts, -2, use_tg )
        !
     ELSE
        !
!$omp parallel do
        DO j = 1, nrxxs
           psic (j) = psic (j) * v(j)
        ENDDO
!$omp end parallel do
        !
        CALL cft3s (psic, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, - 2)
        !
     ENDIF
     !
     !   addition to the total product
     !
     IF( use_tg ) THEN
        !
        ioff   = 0
        !
        DO idx = 1, nogrp
           !
           IF( idx + ibnd - 1 <= m ) THEN
!$omp parallel do
              DO j = 1, n
                 hpsi (j, ibnd+idx-1) = hpsi (j, ibnd+idx-1) + tg_psic( nls(igk(j)) + ioff )
              ENDDO
!$omp end parallel do
           ENDIF
           !
           ioff = ioff + dffts%nr3x * dffts%nsw( me_pool + 1 )
           !
        ENDDO
        !
     ELSE
!$omp parallel do
        DO j = 1, n
           hpsi (j, ibnd)   = hpsi (j, ibnd)   + psic (nls(igk(j)))
        ENDDO
!$omp end parallel do
     ENDIF
     !
  ENDDO
  !
  IF( use_tg ) THEN
     !
     DEALLOCATE( tg_psic )
     DEALLOCATE( tg_v )
     !
  ENDIF
  !
  RETURN
END SUBROUTINE vloc_psi_k
!
!-----------------------------------------------------------------------
SUBROUTINE vloc_psi_nc (lda, n, m, psi, v, hpsi)
  !-----------------------------------------------------------------------
  !
  ! Calculation of Vloc*psi using dual-space technique - noncolinear
  !
  USE parallel_include
  USE kinds,   ONLY : DP
  USE gsmooth, ONLY : nls, nlsm, nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, nrxxs
  USE gvect,   ONLY : nrxx
  USE wvfct,   ONLY : igk
  USE mp_global,     ONLY : nogrp, ogrp_comm, me_pool, nolist, use_task_groups
  USE fft_parallel,  ONLY : tg_cft3s
  USE fft_base,      ONLY : dffts
  USE task_groups,   ONLY : tg_gather
  USE noncollin_module,     ONLY: npol
  USE wavefunctions_module, ONLY: psic_nc
  !
  IMPLICIT NONE
  !
  INTEGER, INTENT(in) :: lda, n, m
  REAL(DP), INTENT(in) :: v(nrxx,4)
  COMPLEX(DP), INTENT(in)   :: psi (lda*npol, m)
  COMPLEX(DP), INTENT(inout):: hpsi (lda,npol,m)
  !
  INTEGER :: ibnd, j,ipol, incr
  COMPLEX(DP) :: sup, sdwn
  !
  LOGICAL :: use_tg
  ! Variables for task groups
  REAL(DP),    ALLOCATABLE :: tg_v(:,:)
  COMPLEX(DP), ALLOCATABLE :: tg_psic(:,:)
  INTEGER :: v_siz, idx, ioff
  !
  !
  incr = 1
  !
  use_tg = ( use_task_groups ) .and. ( m >= nogrp )
  !
  IF( use_tg ) THEN
     v_siz = dffts%nnrx * nogrp
     ALLOCATE( tg_v( v_siz, 4 ) )
     CALL tg_gather( dffts, v(:,1), tg_v(:,1) )
     CALL tg_gather( dffts, v(:,2), tg_v(:,2) )
     CALL tg_gather( dffts, v(:,3), tg_v(:,3) )
     CALL tg_gather( dffts, v(:,4), tg_v(:,4) )
     ALLOCATE( tg_psic( v_siz, npol ) )
     incr = nogrp
  ENDIF
  !
  ! the local potential V_Loc psi. First the psi in real space
  !
  DO ibnd = 1, m, incr

     IF( use_tg ) THEN
        !
        DO ipol = 1, npol
           !
           tg_psic(:,ipol) = ( 0.D0, 0.D0 )
           ioff   = 0
           !
           DO idx = 1, nogrp
              !
              IF( idx + ibnd - 1 <= m ) THEN
                 DO j = 1, n
                    tg_psic( nls( igk(j) ) + ioff, ipol ) = psi( j +(ipol-1)*lda, idx+ibnd-1 )
                 ENDDO
              ENDIF

              ioff = ioff + dffts%nnrx

           ENDDO
           !
           CALL tg_cft3s ( tg_psic(:,ipol), dffts, 2, use_tg )
           !
        ENDDO
        !
     ELSE
        psic_nc = (0.d0,0.d0)
        DO ipol=1,npol
           DO j = 1, n
              psic_nc(nls(igk(j)),ipol) = psi(j+(ipol-1)*lda,ibnd)
           ENDDO
           CALL cft3s (psic_nc(1,ipol), nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, 2)
        ENDDO
     ENDIF

     !
     !   product with the potential v = (vltot+vr) on the smooth grid
     !
     IF( use_tg ) THEN
        DO j=1, nrx1s * nrx2s * dffts%tg_npp( me_pool + 1 )
           sup = tg_psic(j,1) * (tg_v(j,1)+tg_v(j,4)) + &
                 tg_psic(j,2) * (tg_v(j,2)-(0.d0,1.d0)*tg_v(j,3))
           sdwn = tg_psic(j,2) * (tg_v(j,1)-tg_v(j,4)) + &
                  tg_psic(j,1) * (tg_v(j,2)+(0.d0,1.d0)*tg_v(j,3))
           tg_psic(j,1)=sup
           tg_psic(j,2)=sdwn
        ENDDO
     ELSE
        DO j=1, nrxxs
           sup = psic_nc(j,1) * (v(j,1)+v(j,4)) + &
                 psic_nc(j,2) * (v(j,2)-(0.d0,1.d0)*v(j,3))
           sdwn = psic_nc(j,2) * (v(j,1)-v(j,4)) + &
                  psic_nc(j,1) * (v(j,2)+(0.d0,1.d0)*v(j,3))
           psic_nc(j,1)=sup
           psic_nc(j,2)=sdwn
        ENDDO
     ENDIF
     !
     !   back to reciprocal space
     !
     IF( use_tg ) THEN
        !
        DO ipol = 1, npol

           CALL tg_cft3s ( tg_psic(:,ipol), dffts, -2, use_tg )
           !
           ioff   = 0
           !
           DO idx = 1, nogrp
              !
              IF( idx + ibnd - 1 <= m ) THEN
                 DO j = 1, n
                    hpsi (j, ipol, ibnd+idx-1) = hpsi (j, ipol, ibnd+idx-1) + tg_psic( nls(igk(j)) + ioff, ipol )
                 ENDDO
              ENDIF
              !
              ioff = ioff + dffts%nr3x * dffts%nsw( me_pool + 1 )
              !
           ENDDO

        ENDDO
        !
     ELSE

        DO ipol=1,npol
           CALL cft3s (psic_nc(1,ipol), nr1s, nr2s, nr3s, nrx1s, nrx2s, nrx3s, -2)
        ENDDO
        !
        !   addition to the total product
        !
        DO ipol=1,npol
           DO j = 1, n
              hpsi(j,ipol,ibnd) = hpsi(j,ipol,ibnd) + psic_nc(nls(igk(j)),ipol)
           ENDDO
        ENDDO

     ENDIF

  ENDDO

  IF( use_tg ) THEN
     !
     DEALLOCATE( tg_v )
     DEALLOCATE( tg_psic )
     !
  ENDIF
  !
  RETURN
END SUBROUTINE vloc_psi_nc
