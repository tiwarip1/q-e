!
! Copyright (C) 2001-2011 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-------------------------------------------------------------------------
SUBROUTINE latgen(ibrav,celldm,a1,a2,a3,omega)
  !-----------------------------------------------------------------------
  !     sets up the crystallographic vectors a1, a2, and a3.
  !
  !     ibrav is the structure index:
  !       1  cubic P (sc)                8  orthorhombic P
  !       2  cubic F (fcc)               9  1-face (C) centered orthorhombic
  !       3  cubic I (bcc)              10  all face centered orthorhombic
  !       4  hexagonal and trigonal P   11  body centered orthorhombic
  !       5  trigonal R, 3-fold axis c  12  monoclinic P (unique axis: c)
  !       6  tetragonal P (st)          13  one face (base) centered monoclinic
  !       7  tetragonal I (bct)         14  triclinic P
  !     Also accepted:
  !       0  "free" structure          -12  monoclinic P (unique axis: b)
  !      -3  cubic bcc with a more symmetric choice of axis
  !      -5  trigonal R, threefold axis along (111)
  !      -9  alternate description for base centered orthorhombic
  !     -13  one face (base) centered monoclinic (unique axis: b)
  !      91  1-face (A) centered orthorombic
  !
  !     celldm are parameters which fix the shape of the unit cell
  !     omega is the unit-cell volume
  !
  !     NOTA BENE: all axis sets are right-handed
  !     Boxes for US PPs do not work properly with left-handed axis
  !
  USE kinds, ONLY: DP
  IMPLICIT NONE
  INTEGER, INTENT(in) :: ibrav
  real(DP), INTENT(inout) :: celldm(6)
  real(DP), INTENT(inout) :: a1(3), a2(3), a3(3)
  real(DP), INTENT(out) :: omega
  !
  real(DP), PARAMETER:: sr2 = 1.414213562373d0, &
                        sr3 = 1.732050807569d0
  INTEGER :: i,j,k,l,iperm,ir
  real(DP) :: term, cbya, s, term1, term2, singam, sen
  !
  !  user-supplied lattice vectors
  !
  IF (ibrav == 0) THEN
     IF (sqrt( a1(1)**2 + a1(2)**2 + a1(3)**2 ) == 0 )  &
         CALL errore ('latgen', 'wrong at for ibrav=0', 1)
     IF (sqrt( a2(1)**2 + a2(2)**2 + a2(3)**2 ) == 0 )  &
         CALL errore ('latgen', 'wrong at for ibrav=0', 2)
     IF (sqrt( a3(1)**2 + a3(2)**2 + a3(3)**2 ) == 0 )  &
         CALL errore ('latgen', 'wrong at for ibrav=0', 3)

     IF ( celldm(1) /= 0.D0 ) THEN
     !
     ! ... input at are in units of alat => convert them to a.u.
     !
         a1(:) = a1(:) * celldm(1)
         a2(:) = a2(:) * celldm(1)
         a3(:) = a3(:) * celldm(1)
     ELSE
     !
     ! ... input at are in atomic units: define celldm(1) from a1
     !
         celldm(1) = sqrt( a1(1)**2 + a1(2)**2 + a1(3)**2 )
     ENDIF
     !
  ELSE
     a1(:) = 0.d0
     a2(:) = 0.d0
     a3(:) = 0.d0
  ENDIF
  !
  IF (celldm (1) <= 0.d0) CALL errore ('latgen', 'wrong celldm(1)', abs(ibrav) )
  !
  !  index of bravais lattice supplied
  !
  IF (ibrav == 1) THEN
     !
     !     simple cubic lattice
     !
     a1(1)=celldm(1)
     a2(2)=celldm(1)
     a3(3)=celldm(1)
     !
  ELSEIF (ibrav == 2) THEN
     !
     !     fcc lattice
     !
     term=celldm(1)/2.d0
     a1(1)=-term
     a1(3)=term
     a2(2)=term
     a2(3)=term
     a3(1)=-term
     a3(2)=term
     !
  ELSEIF (abs(ibrav) == 3) THEN
     !
     !     bcc lattice
     !
     term=celldm(1)/2.d0
     DO ir=1,3
        a1(ir)=term
        a2(ir)=term
        a3(ir)=term
     ENDDO
     IF ( ibrav < 0 ) THEN
        a1(1)=-a1(1)
        a2(2)=-a2(2)
        a3(3)=-a3(3)
     ELSE
        a2(1)=-a2(1)
        a3(1)=-a3(1)
        a3(2)=-a3(2)
     ENDIF
     !
  ELSEIF (ibrav == 4) THEN
     !
     !     hexagonal lattice
     !
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     cbya=celldm(3)
     a1(1)=celldm(1)
     a2(1)=-celldm(1)/2.d0
     a2(2)=celldm(1)*sr3/2.d0
     a3(3)=celldm(1)*cbya
     !
  ELSEIF (abs(ibrav) == 5) THEN
     !
     !     trigonal lattice
     !
     IF (celldm (4) <= -0.5_dp .or. celldm (4) >= 1.0_dp) &
          CALL errore ('latgen', 'wrong celldm(4)', abs(ibrav))
     !
     term1=sqrt(1.0_dp + 2.0_dp*celldm(4))
     term2=sqrt(1.0_dp - celldm(4))
     !
     IF ( ibrav == 5) THEN
        !     threefold axis along c (001)
        a2(2)=sr2*celldm(1)*term2/sr3
        a2(3)=celldm(1)*term1/sr3
        a1(1)=celldm(1)*term2/sr2
        a1(2)=-a1(1)/sr3
        a1(3)= a2(3)
        a3(1)=-a1(1)
        a3(2)= a1(2)
        a3(3)= a2(3)
     ELSEIF ( ibrav == -5) THEN
        !     threefold axis along (111)
        ! Notice that in the cubic limit (alpha=90, celldm(4)=0, term1=term2=1)
        ! does not yield the x,y,z axis, but an equivalent rotated triplet:
        !    a/3 (-1,2,2), a/3 (2,-1,2), a/3 (2,2,-1)
        ! If you prefer the x,y,z axis as cubic limit, you should modify the
        ! definitions of a1(1) and a1(2) as follows:'
        !    a1(1) = celldm(1)*(term1+2.0_dp*term2)/3.0_dp
        !    a1(2) = celldm(1)*(term1-term2)/3.0_dp
        ! (info by G. Pizzi and A. Cepellotti)
        !
        a1(1) = celldm(1)*(term1-2.0_dp*term2)/3.0_dp
        a1(2) = celldm(1)*(term1+term2)/3.0_dp
        a1(3) = a1(2)
        a2(1) = a1(3)
        a2(2) = a1(1)
        a2(3) = a1(2)
        a3(1) = a1(2)
        a3(2) = a1(3)
        a3(3) = a1(1)
     ENDIF
  ELSEIF (ibrav == 6) THEN
     !
     !     tetragonal lattice
     !
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     cbya=celldm(3)
     a1(1)=celldm(1)
     a2(2)=celldm(1)
     a3(3)=celldm(1)*cbya
     !
  ELSEIF (ibrav == 7) THEN
     !
     !     body centered tetragonal lattice
     !
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     cbya=celldm(3)
     a2(1)=celldm(1)/2.d0
     a2(2)=a2(1)
     a2(3)=cbya*celldm(1)/2.d0
     a1(1)= a2(1)
     a1(2)=-a2(1)
     a1(3)= a2(3)
     a3(1)=-a2(1)
     a3(2)=-a2(1)
     a3(3)= a2(3)
     !
  ELSEIF (ibrav == 8) THEN
     !
     !     Simple orthorhombic lattice
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     a1(1)=celldm(1)
     a2(2)=celldm(1)*celldm(2)
     a3(3)=celldm(1)*celldm(3)
     !
  ELSEIF ( abs(ibrav) == 9) THEN
     !
     !     One face (base) centered orthorhombic lattice  (C type)
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', &
                                                                 abs(ibrav))
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', &
                                                                 abs(ibrav))
     !
     IF ( ibrav == 9 ) THEN
        !   old PWscf description
        a1(1) = 0.5d0 * celldm(1)
        a1(2) = a1(1) * celldm(2)
        a2(1) = - a1(1)
        a2(2) = a1(2)
     ELSE
        !   alternate description
        a1(1) = 0.5d0 * celldm(1)
        a1(2) =-a1(1) * celldm(2)
        a2(1) = a1(1)
        a2(2) =-a1(2)
     ENDIF
     a3(3) = celldm(1) * celldm(3)
     !
  ELSEIF ( ibrav == 91 ) THEN
     !
     !     One face (base) centered orthorhombic lattice  (A type)
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     a1(1) = celldm(1)
     a2(2) = celldm(1) * celldm(2) * 0.5_DP
     a2(3) = - celldm(1) * celldm(3) * 0.5_DP
     a3(2) = a2(2)
     a3(3) = - a2(3)
     !
  ELSEIF (ibrav == 10) THEN
     !
     !     All face centered orthorhombic lattice
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     a2(1) = 0.5d0 * celldm(1)
     a2(2) = a2(1) * celldm(2)
     a1(1) = a2(1)
     a1(3) = a2(1) * celldm(3)
     a3(2) = a2(1) * celldm(2)
     a3(3) = a1(3)
     !
  ELSEIF (ibrav == 11) THEN
     !
     !     Body centered orthorhombic lattice
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     !
     a1(1) = 0.5d0 * celldm(1)
     a1(2) = a1(1) * celldm(2)
     a1(3) = a1(1) * celldm(3)
     a2(1) = - a1(1)
     a2(2) = a1(2)
     a2(3) = a1(3)
     a3(1) = - a1(1)
     a3(2) = - a1(2)
     a3(3) = a1(3)
     !
  ELSEIF (ibrav == 12) THEN
     !
     !     Simple monoclinic lattice, unique (i.e. orthogonal to a) axis: c
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     IF (abs(celldm(4))>=1.d0) CALL errore ('latgen', 'wrong celldm(4)', ibrav)
     !
     sen=sqrt(1.d0-celldm(4)**2)
     a1(1)=celldm(1)
     a2(1)=celldm(1)*celldm(2)*celldm(4)
     a2(2)=celldm(1)*celldm(2)*sen
     a3(3)=celldm(1)*celldm(3)
     !
  ELSEIF (ibrav ==-12) THEN
     !
     !     Simple monoclinic lattice, unique axis: b (more common)
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)',-ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)',-ibrav)
     IF (abs(celldm(5))>=1.d0) CALL errore ('latgen', 'wrong celldm(5)',-ibrav)
     !
     sen=sqrt(1.d0-celldm(5)**2)
     a1(1)=celldm(1)
     a2(2)=celldm(1)*celldm(2)
     a3(1)=celldm(1)*celldm(3)*celldm(5)
     a3(3)=celldm(1)*celldm(3)*sen
     !
  ELSEIF (ibrav == 13) THEN
     !
     !     One face centered monoclinic lattice unique axis c
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     IF (abs(celldm(4))>=1.d0) CALL errore ('latgen', 'wrong celldm(4)', ibrav)
     !
     sen = sqrt( 1.d0 - celldm(4) ** 2 )
     a1(1) = 0.5d0 * celldm(1)
     a1(3) =-a1(1) * celldm(3)
     a2(1) = celldm(1) * celldm(2) * celldm(4)
     a2(2) = celldm(1) * celldm(2) * sen
     a3(1) = a1(1)
     a3(3) =-a1(3)
  ELSEIF (ibrav == -13) THEN
     !
     !     One face centered monoclinic lattice unique axis b
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)',-ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)',-ibrav)
     IF (abs(celldm(5))>=1.d0) CALL errore ('latgen', 'wrong celldm(5)',-ibrav)
     !
     sen = sqrt( 1.d0 - celldm(5) ** 2 )
     a1(1) = 0.5d0 * celldm(1)
     a1(2) =-a1(1) * celldm(2)
     a2(1) = a1(1)
     a2(2) =-a1(2)
     a3(1) = celldm(1) * celldm(3) * celldm(5)
     a3(3) = celldm(1) * celldm(3) * sen
     !
  ELSEIF (ibrav == 14) THEN
     !
     !     Triclinic lattice
     !
     IF (celldm (2) <= 0.d0) CALL errore ('latgen', 'wrong celldm(2)', ibrav)
     IF (celldm (3) <= 0.d0) CALL errore ('latgen', 'wrong celldm(3)', ibrav)
     IF (abs(celldm(4))>=1.d0) CALL errore ('latgen', 'wrong celldm(4)', ibrav)
     IF (abs(celldm(5))>=1.d0) CALL errore ('latgen', 'wrong celldm(5)', ibrav)
     IF (abs(celldm(6))>=1.d0) CALL errore ('latgen', 'wrong celldm(6)', ibrav)
     !
     singam=sqrt(1.d0-celldm(6)**2)
     term= (1.d0+2.d0*celldm(4)*celldm(5)*celldm(6)             &
          -celldm(4)**2-celldm(5)**2-celldm(6)**2)
     IF (term < 0.d0) CALL errore &
        ('latgen', 'celldm do not make sense, check your data', ibrav)
     term= sqrt(term/(1.d0-celldm(6)**2))
     a1(1)=celldm(1)
     a2(1)=celldm(1)*celldm(2)*celldm(6)
     a2(2)=celldm(1)*celldm(2)*singam
     a3(1)=celldm(1)*celldm(3)*celldm(5)
     a3(2)=celldm(1)*celldm(3)*(celldm(4)-celldm(5)*celldm(6))/singam
     a3(3)=celldm(1)*celldm(3)*term
     !
  ELSE
     !
     CALL errore('latgen',' nonexistent bravais lattice',ibrav)
     !
  ENDIF
  !
  !  calculate unit-cell volume omega
  !
  CALL volume (1.0_dp, a1, a2, a3, omega)
  !
  RETURN
  !
END SUBROUTINE latgen
!
!-------------------------------------------------------------------------
SUBROUTINE at2celldm (ibrav,alat,a1,a2,a3,celldm)
  !-----------------------------------------------------------------------
  !
  !     Returns celldm parameters from lattice vectors
  !     Tries to guess ibrav if not specified (ibrav=0)
  !     See latgen for definition of celldm and lattice vectors
  !
  USE kinds, ONLY: DP
  IMPLICIT NONE
  INTEGER, INTENT(in) :: ibrav
  real(DP), INTENT(in) :: alat, a1(3), a2(3), a3(3)
  real(DP), INTENT(out) :: celldm(6)
  INTEGER :: jbrav
  INTEGER, EXTERNAL :: at2ibrav
  !
  celldm = 0.d0
  jbrav = 0
  !
  IF ( ibrav == 0 ) THEN
     jbrav= at2ibrav (a1, a2, a3)
     IF ( jbrav == 0 ) CALL infomsg('at2celldm', &
          'could not determine ibrav for lattice vectors')
  ELSE
     jbrav = ibrav
  ENDIF

  SELECT CASE  ( jbrav )
  CASE (1)
     celldm(1) = sqrt( dot_product (a1,a1) )
  CASE (2)
     celldm(1) = sqrt( dot_product (a1,a1) * 2.0_dp )
  CASE (3,-3)
     celldm(1) = sqrt( dot_product (a1,a1) / 3.0_dp ) * 2.0_dp
  CASE (4)
     celldm(1) = sqrt( dot_product (a1,a1) )
     celldm(3) = sqrt( dot_product (a3,a3) ) / celldm(1)
  CASE (5, -5 )
     celldm(1) = sqrt( dot_product (a1,a1) )
     celldm(4) = dot_product(a1(:),a2(:)) / celldm(1) &
                 / sqrt( dot_product( a2,a2) )
  CASE (6)
     celldm(1)= sqrt( dot_product (a1,a1) )
     celldm(3)= sqrt( dot_product (a3,a3) ) / celldm(1)
  CASE (7)
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(3) = abs(a1(3)/a1(1))
  CASE (8)
     celldm(1) = sqrt( dot_product (a1,a1) )
     celldm(2) = sqrt( dot_product (a2,a2) ) / celldm(1)
     celldm(3) = sqrt( dot_product (a3,a3) ) / celldm(1)
  CASE (9, -9 )
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(2) = abs(a2(2))*2.0_dp/celldm(1)
     celldm(3) = abs(a3(3))/celldm(1)
  CASE (91 )
     celldm(1) = sqrt( dot_product (a1,a1) )
     celldm(2) = abs (a2(2)/a1(1))*2.0_dp/celldm(1)
     celldm(3) = abs (a3(3)/a1(1))*2.0_dp/celldm(1)
  CASE (10)
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(2) = abs(a2(2))*2.0_dp/celldm(1)
     celldm(3) = abs(a3(3))*2.0_dp/celldm(1)
  CASE (11)
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(2) = abs(a1(2))*2.0_dp/celldm(1)
     celldm(3) = abs(a1(3))*2.0_dp/celldm(1)
  CASE (12,-12)
     celldm(1) = sqrt( dot_product (a1,a1) )
     celldm(2) = sqrt( dot_product(a2(:),a2(:)) ) / celldm(1)
     celldm(3) = sqrt( dot_product(a3(:),a3(:)) ) / celldm(1)
     IF ( jbrav == 12 ) THEN
        celldm(4) = dot_product(a1(:),a2(:)) / celldm(1) / &
             sqrt(dot_product(a2(:),a2(:)))
     ELSE
        celldm(5) = dot_product(a1(:),a3(:)) / celldm(1) / &
             sqrt(dot_product(a3(:),a3(:)))
     ENDIF
  CASE (13)
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(2) = sqrt( dot_product(a2(:),a2(:))) / celldm(1)
     celldm(3) = abs (a1(3)/a1(1))
     celldm(4) = a2(1)/a1(1)/celldm(2)/2.0_dp
     !     SQRT(DOT_PRODUCT(a1(:),a1(:)) * DOT_PRODUCT(a2(:),a2(:)))
     !celldm(4) = DOT_PRODUCT(a1(:),a2(:)) / &
     !     SQRT(DOT_PRODUCT(a1(:),a1(:)) * DOT_PRODUCT(a2(:),a2(:)))
  CASE (-13)
     celldm(1) = abs(a1(1))*2.0_dp
     celldm(2) = abs (a2(2)/a2(1))
     celldm(3) = sqrt( dot_product(a3(:),a3(:))) / celldm(1)
     celldm(5) = a3(1)/a1(1)/celldm(3)/2.0_dp
     !celldm(5) = DOT_PRODUCT(a1(:),a3(:)) / &
     !     SQRT(DOT_PRODUCT(a1(:),a1(:)) * DOT_PRODUCT(a3(:),a3(:)))
  CASE (0,14)
     celldm(1) = sqrt(dot_product(a1(:),a1(:)))
     celldm(2) = sqrt( dot_product(a2(:),a2(:))) / celldm(1)
     celldm(3) = sqrt( dot_product(a3(:),a3(:))) / celldm(1)
     celldm(4) = dot_product(a3(:),a2(:))/sqrt(dot_product(a2(:),a2(:)) * &
          dot_product(a3(:),a3(:)))
     celldm(5) = dot_product(a3(:),a1(:)) / celldm(1) / &
          sqrt( dot_product(a3(:),a3(:)))
     celldm(6) = dot_product(a1(:),a2(:)) / celldm(1) / &
          sqrt(dot_product(a2(:),a2(:)))
  CASE DEFAULT
     CALL infomsg('at2celldm', 'wrong ibrav?')
  END SELECT
  !
  IF ( alat > 0.0_dp) celldm(1) = celldm(1)*alat
  !
END SUBROUTINE at2celldm
!
INTEGER FUNCTION at2ibrav (a1, a2, a3) RESULT (ibrav)
  !
  !     Returns ibrav from lattice vectors if recognized, 0 otherwise
  !
  USE kinds, ONLY: dp
  IMPLICIT NONE
  REAL(dp), INTENT (in) :: a1(3), a2(3), a3(3)
  REAL(dp) :: v1, v2, v3, cosab, cosac, cosbc
  !
  ibrav =0
  !
  v1 = sqrt( dot_product( a1,a1 ) )
  v2 = sqrt( dot_product( a2,a2 ) )
  v3 = sqrt( dot_product( a3,a3 ) )
  cosbc = dot_product(a2,a3)/v2/v3
  cosac = dot_product(a1,a3)/v1/v3
  cosab = dot_product(a1,a2)/v1/v2
  !
  IF ( eqq(v1,v2) .and. eqq(v1,v3) ) THEN
     ! Case: a=b=c
     IF (eqq(cosab,cosac) .and. eqq(cosab,cosbc)) THEN
        ! Case: alpha = beta = gamma
        IF ( eqq(cosab,0.0_dp) ) THEN
           ! Cubic P - ibrav=1
           ibrav = 1
        ELSEIF ( eqq(cosab,0.5_dp) ) THEN
           ! Cubic F - ibrav=2
           ibrav = 2
        ELSEIF ( eqq(cosab,-1.0_dp/3.0_dp) ) THEN
           ! Cubic I - ibrav=-3
           ibrav = -3
        ELSE
           IF ( eqq(abs(a1(3)),abs(a2(3))) .and. eqq(abs(a2(3)),abs(a3(3))) ) THEN
              ! Trigonal 001 axis
              ibrav =5
           ELSE
              ! Trigonal, 111 axis
              ibrav =-5
           ENDIF
           !
        ENDIF
        !
     ELSEIF ( eqq(cosab,cosac) .and. neqq(cosab,cosbc) ) THEN
        IF ( eqq(abs(a1(1)),abs(a1(2))) .and. &
             eqq(abs(a2(1)),abs(a2(2))) ) THEN
           ! Tetragonal I
           ibrav = 7
        ELSE
           ! Cubic I - ibrav=3
           ibrav = 3
        ENDIF
     ELSEIF ( eqq(cosab,-cosac) .and. eqq(cosab,cosbc) .and. &
          eqq(cosab,1.0_dp/3.0_dp) ) THEN
        ! Cubic I - ibrav=3
        ibrav = 3
     ELSEIF ( eqq(abs(a1(1)),abs(a2(1))) .and. &
               eqq(abs(a2(2)),abs(a2(2))) ) THEN
        ! Orthorhombic body-centered
        ibrav = 11
     ENDIF
     !
  ELSEIF ( eqq(v1,v2) .and. neqq(v1,v3) ) THEN
     ! Case: a=b/=c
     IF ( eqq(cosab,0.0_dp) .and. eqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Case: alpha = beta = gamma = 90
        ! Simple tetragonal
        ibrav = 6
     ELSEIF ( eqq(cosab,-0.5_dp) .and. eqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Case: alpha = 120, beta = gamma = 90 => simple hexagonal
        ! Simple hexagonal
        ibrav = 4
     ELSEIF ( eqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Orthorhombic bco
        IF ( eqq(a1(1),a2(1)) .and. eqq(a1(2),-a2(2))) THEN
           ibrav = -9
        ELSEIF ( eqq(a1(1),-a2(1)) .and. eqq(a1(2),a2(2))) THEN
           ibrav = 9
        ENDIF
     ELSE
        ! bco (unique axis b)
        ibrav =-13
     ENDIF

  ELSEIF ( eqq(v1,v3) .and. neqq(v1,v2) ) THEN
     ! Case: a=c/=b
     ! Monoclinic bco (unique axis c)
     ibrav = 13
     !
  ELSEIF ( eqq(v2,v3) .and. neqq(v1,v2) ) THEN
     ! Case: a/=b=c
     ! Orthorhombic 1-face bco
     ibrav = 91
     !
  ELSEIF ( neqq(v1,v2) .and. neqq(v1,v3) .and. neqq(v2,v3) ) THEN
     ! Case: a/=b/=c
     IF ( eqq(cosab,0.0_dp) .and. eqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Case: alpha = beta = gamma = 90
        ! Orthorhombic P
        ibrav = 8
     ELSEIF ( neqq(cosab,0.0_dp) .and. eqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Case: alpha /= 90,  beta = gamma = 90
        ! Monoclinic P, unique axis c
        ibrav = 12
     ELSEIF ( eqq(cosab,0.0_dp) .and. neqq(cosac,0.0_dp) .and. eqq(cosbc,0.0_dp) ) THEN
        ! Case: beta /= 90, alpha = gamma = 90
        ! Monoclinic P, unique axis b
        ibrav =-12
     ELSEIF ( neqq(cosab,0.0_dp) .and. neqq(cosac,0.0_dp) .and. neqq(cosbc,0.0_dp) ) THEN
        ! Case: alpha /= 90, beta /= 90, gamma /= 90
        IF ( eqq(abs(a1(1)),abs(a2(1))) .and. eqq(abs(a1(3)),abs(a3(3))) .and. &
             eqq(abs(a2(2)),abs(a3(2))) ) THEN
        ! Orthorhombic F
           ibrav = 10
        ELSE
           ! Triclinic
           ibrav = 14
        ENDIF
     ENDIF
     !
  ENDIF
  !
CONTAINS
  !
  LOGICAL FUNCTION eqq (x,y)
    REAL(dp), INTENT (in) :: x,y
    eqq = abs(x-y) < 1.0d-5
  END FUNCTION eqq
  LOGICAL FUNCTION neqq (x,y)
    REAL(dp), INTENT (in) :: x,y
    neqq= abs(x-y) > 1.0d-5
  END FUNCTION neqq
  !
END FUNCTION at2ibrav
!
SUBROUTINE abc2celldm ( ibrav, a,b,c,cosab,cosac,cosbc, celldm )
  !
  !  returns internal parameters celldm from crystallographics ones
  !
  USE kinds,     ONLY: dp
  USE constants, ONLY: bohr_radius_angs
  IMPLICIT NONE
  !
  INTEGER,  INTENT (in) :: ibrav
  REAL(DP), INTENT (in) :: a,b,c, cosab, cosac, cosbc
  REAL(DP), INTENT (out) :: celldm(6)
  !
  IF (a <= 0.0_dp) CALL errore('abc2celldm','incorrect lattice parameter (a)',1)
  IF (b <  0.0_dp) CALL errore('abc2celldm','incorrect lattice parameter (b)',1)
  IF (c <  0.0_dp) CALL errore('abc2celldm','incorrect lattice parameter (c)',1)
  IF ( abs (cosab) > 1.0_dp) CALL errore('abc2celldm', &
                   'incorrect lattice parameter (cosab)',1)
  IF ( abs (cosac) > 1.0_dp) CALL errore('abc2celldm', &
                   'incorrect lattice parameter (cosac)',1)
  IF ( abs (cosbc) > 1.0_dp) CALL errore('abc2celldm', &
       'incorrect lattice parameter (cosbc)',1)
  !
  celldm(1) = a / bohr_radius_angs
  celldm(2) = b / a
  celldm(3) = c / a
  !
  IF ( ibrav == 14 .or. ibrav == 0 ) THEN
     !
     ! ... triclinic lattice
     !
     celldm(4) = cosbc
     celldm(5) = cosac
     celldm(6) = cosab
     !
  ELSEIF ( ibrav ==-12 .or. ibrav ==-13 ) THEN
     !
     ! ... monoclinic P or base centered lattice, unique axis b
     !
     celldm(4) = 0.0_dp
     celldm(5) = cosac
     celldm(6) = 0.0_dp
     !
  ELSEIF ( ibrav ==-5 .or. ibrav ==5 .or. ibrav ==12 .or. ibrav ==13 ) THEN
     !
     ! ... trigonal and monoclinic lattices, unique axis c
     !
     celldm(4) = cosab
     celldm(5) = 0.0_dp
     celldm(6) = 0.0_dp
     !
  ELSE
     !
     celldm(4) = 0.0_dp
     celldm(5) = 0.0_dp
     celldm(6) = 0.0_dp
     !
  ENDIF
  !
END SUBROUTINE abc2celldm
!
SUBROUTINE celldm2abc ( ibrav, celldm, a,b,c,cosab,cosac,cosbc )
  !
  !  returns crystallographic parameters a,b,c from celldm
  !
  USE kinds,     ONLY: dp
  USE constants, ONLY: bohr_radius_angs
  IMPLICIT NONE
  !
  INTEGER,  INTENT (in) :: ibrav
  REAL(DP), INTENT (in) :: celldm(6)
  REAL(DP), INTENT (out) :: a,b,c, cosab, cosac, cosbc
  !
  !
  a = celldm(1) * bohr_radius_angs
  b = celldm(1)*celldm(2) * bohr_radius_angs
  c = celldm(1)*celldm(3) * bohr_radius_angs
  !
  IF ( ibrav == 14 .or. ibrav == 0 ) THEN
     !
     ! ... triclinic lattice
     !
     cosbc = celldm(4)
     cosac = celldm(5)
     cosab = celldm(6)
     !
  ELSEIF ( ibrav ==-12 .or. ibrav ==-13 ) THEN
     !
     ! ... monoclinic P or base centered lattice, unique axis b
     !
     cosab = 0.0_dp
     cosac = celldm(5)
     cosbc = 0.0_dp
     !
  ELSEIF ( ibrav ==-5 .or. ibrav ==5 .or. ibrav ==12 .or. ibrav ==13 ) THEN
     !
     ! ... trigonal and monoclinic lattices, unique axis c
     !
     cosab = celldm(4)
     cosac = 0.0_dp
     cosbc = 0.0_dp
     !
  ELSE
     cosab = 0.0_dp
     cosac = 0.0_dp
     cosbc = 0.0_dp
  ENDIF
  !
END SUBROUTINE celldm2abc
