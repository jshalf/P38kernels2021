! ________________________________________________________________________________________
!
! *** Copyright Notice ***
!
! "Particle In Cell Scalable Application Resource (PICSAR) v2", Copyright (c)
! 2016, The Regents of the University of California, through Lawrence Berkeley
! National Laboratory (subject to receipt of any required approvals from the
! U.S. Dept. of Energy). All rights reserved.
!
! If you have questions about your rights to use or distribute this software,
! please contact Berkeley Lab's Innovation & Partnerships Office at IPO@lbl.gov.
!
! NOTICE.
! This Software was developed under funding from the U.S. Department of Energy
! and the U.S. Government consequently retains certain rights. As such, the U.S.
! Government has been granted for itself and others acting on its behalf a
! paid-up, nonexclusive, irrevocable, worldwide license in the Software to
! reproduce, distribute copies to the public, prepare derivative works, and
! perform publicly and display publicly, and to permit other to do so.
!
! DIRECT_CURRENT_DEPOSITION_3D.F90
!
! Developers
! Henri Vincenti, ! Mathieu Lobet
!
! Description:
! This file contains subroutines for the direct current deposition in 3D.
!
! List of subroutines:
!
! Classical non-optimized:
! - depose_jxjyjz_scalar_1_1_1
!
! - current_reduction_1_1_1
!
! ______________________________________________________________________________


! ______________________________________________________________________________
!> @brief
!> Order 1 3D scalar direct current deposition routine (rho*v)
!> This version does not vectorize on SIMD architectures
!
!> @author
!> Henri Vincenti
!
!> @date
!> Creation 2015
!
!> @param[in] np Number of particles
!> @param[in] xp 1D array of x-coordinates of particles
!> @param[in] yp 1D array of x-coordinates of particles
!> @param[in] zp 1D array of x-coordinates of particles
!> @param[in] uxp 1D array of ux-velocity components of particles
!> @param[in] uyp 1D array of ux-velocity components of particles
!> @param[in] uzp 1D array of ux-velocity components of particles
!> @param[in] gaminv 1D array of the inverse 1/gamma-factor of particles
!> @param[in] w 1D array of the weghts of particles
!> @param[in] q charge of current species (scalar)
!> @param[in] xmin x-minimum boundary of current tile
!> @param[in] ymin y-minimum boundary of current tile
!> @param[in] zmin z-minimum boundary of current tile
!> @param[in] dt time step (scalar)
!> @param[in] dx mesh size along x (scalar)
!> @param[in] dy mesh size along y (scalar)
!> @param[in] dz mesh size along z (scalar)
!> @param[inout] jx x-current component (3D array)
!> @param[in] jx_nguard number of guard cells of the jx array in each direction
!> (1d array containing 3 integers)
!> @param[in] jx_nvalid number of valid gridpoints (i.e. not guard cells) of the
!> jx array (1d array containing 3 integers)
!> @param[inout] jy y-current component (3D array)
!> @param[in] jy_nguard number of guard cells of the jy array in each direction
!>  (1d array containing 3 integers)
!> @param[in] jy_nvalid number of valid gridpoints (i.e. not guard cells) of the
!> jy array (1d array containing 3 integers)
!> @param[inout] jz z-current component (3D array)
!> @param[in] jz_nguard number of guard cells of the jz array in each direction
!> (1d array containing 3 integers)
!> @param[in] jz_nvalid number of valid gridpoints (i.e. not guard cells) of the
!> jz array (1d array containing 3 integers)
!> @warning arrays jx, jy, jz should be set to 0 before entering this subroutine.
! ________________________________________________________________________________________
SUBROUTINE depose_jxjyjz_scalar_1_1_1( jx, jx_nguard, jx_nvalid, jy, jy_nguard,       &
  jy_nvalid, jz, jz_nguard, jz_nvalid, np, xp, yp, zp, uxp, uyp, uzp, gaminv, w, q,     &
  xmin, ymin, zmin, dt, dx, dy, dz)     !#do not wrap
  USE constants
  IMPLICIT NONE
  INTEGER(idp)             :: np
  INTEGER(idp), intent(in) :: jx_nguard(3), jx_nvalid(3), jy_nguard(3), jy_nvalid(3), &
  jz_nguard(3), jz_nvalid(3)
  REAL(num), intent(IN OUT):: jx(-jx_nguard(1):jx_nvalid(1)+jx_nguard(1)-1,           &
  -jx_nguard(2):jx_nvalid(2)+jx_nguard(2)-1,                                          &
  -jx_nguard(3):jx_nvalid(3)+jx_nguard(3)-1 )
  REAL(num), intent(IN OUT):: jy(-jy_nguard(1):jy_nvalid(1)+jy_nguard(1)-1,           &
  -jy_nguard(2):jy_nvalid(2)+jy_nguard(2)-1,                                          &
  -jy_nguard(3):jy_nvalid(3)+jy_nguard(3)-1 )
  REAL(num), intent(IN OUT):: jz(-jz_nguard(1):jz_nvalid(1)+jz_nguard(1)-1,           &
  -jz_nguard(2):jz_nvalid(2)+jz_nguard(2)-1,                                          &
  -jz_nguard(3):jz_nvalid(3)+jz_nguard(3)-1 )
  REAL(num), DIMENSION(np) :: xp, yp, zp, uxp, uyp, uzp, w, gaminv
  REAL(num)                :: q, dt, dx, dy, dz, xmin, ymin, zmin
  REAL(num)                :: dxi, dyi, dzi, xint, yint, zint
  REAL(num)                :: x, y, z, xmid, ymid, zmid, vx, vy, vz, invvol, dts2dx,  &
  dts2dy, dts2dz
  REAL(num)                :: wq, wqx, wqy, wqz, clightsq
  REAL(num), DIMENSION(2)  :: sx(0:1), sy(0:1), sz(0:1), sx0(0:1), sy0(0:1), sz0(0:1)
  REAL(num), PARAMETER     :: onesixth=1.0_num/6.0_num, twothird=2.0_num/3.0_num
  INTEGER(idp)             :: j, k, l, j0, k0, l0, ip

  dxi = 1.0_num/dx
  dyi = 1.0_num/dy
  dzi = 1.0_num/dz
  invvol = dxi*dyi*dzi
  dts2dx = 0.5_num*dt*dxi
  dts2dy = 0.5_num*dt*dyi
  dts2dz = 0.5_num*dt*dzi
  clightsq = 1.0_num/clight**2
  sx=0.0_num;sy=0.0_num;sz=0.0_num;
  sx0=0.0_num;sy0=0.0_num;sz0=0.0_num;

  ! LOOP ON PARTICLES
  ! Prevent loop to vectorize (dependencies)
  !DIR$ NOVECTOR
  DO ip=1, np

    ! --- computes position in  grid units at (n+1)
    x = (xp(ip)-xmin)*dxi
    y = (yp(ip)-ymin)*dyi
    z = (zp(ip)-zmin)*dzi

    ! Computes velocity
    vx = uxp(ip)*gaminv(ip)
    vy = uyp(ip)*gaminv(ip)
    vz = uzp(ip)*gaminv(ip)

    ! --- computes particles weights
    wq=q*w(ip)
    wqx=wq*invvol*vx
    wqy=wq*invvol*vy
    wqz=wq*invvol*vz

    ! Gets position in grid units at (n+1/2) for computing rho(n+1/2)
    xmid=x-dts2dx*vx
    ymid=y-dts2dy*vy
    zmid=z-dts2dz*vz

    ! --- finds node of cell containing particles for current positions
    j=floor(xmid)
    k=floor(ymid)
    l=floor(zmid)
    j0=floor(xmid-0.5_num)
    k0=floor(ymid-0.5_num)
    l0=floor(zmid-0.5_num)

    ! --- computes set of coefficients for node centered quantities
    xint = xmid-j
    yint = ymid-k
    zint = zmid-l
    sx( 0) = 1.0_num-xint
    sx( 1) = xint
    sy( 0) = 1.0_num-yint
    sy( 1) = yint
    sz( 0) = 1.0_num-zint
    sz( 1) = zint

    ! --- computes set of coefficients for staggered quantities
    xint = xmid-j0-0.5_num
    yint = ymid-k0-0.5_num
    zint = zmid-l0-0.5_num
    sx0( 0) = 1.0_num-xint
    sx0( 1) = xint
    sy0( 0) = 1.0_num-yint
    sy0( 1) = yint
    sz0( 0) = 1.0_num-zint
    sz0( 1) = zint

    ! --- add current contributions in the form rho(n+1/2)v(n+1/2)
    ! - JX
    jx(j0, k, l  )    = jx(j0, k, l  )  +   sx0(0)*sy(0)*sz(0)*wqx
    jx(j0+1, k, l  )    = jx(j0+1, k, l  )  +   sx0(1)*sy(0)*sz(0)*wqx
    jx(j0, k+1, l  )    = jx(j0, k+1, l  )  +   sx0(0)*sy(1)*sz(0)*wqx
    jx(j0+1, k+1, l  )    = jx(j0+1, k+1, l  )  +   sx0(1)*sy(1)*sz(0)*wqx
    jx(j0, k, l+1)    = jx(j0, k, l+1)  +   sx0(0)*sy(0)*sz(1)*wqx
    jx(j0+1, k, l+1)    = jx(j0+1, k, l+1)  +   sx0(1)*sy(0)*sz(1)*wqx
    jx(j0, k+1, l+1)    = jx(j0, k+1, l+1)  +   sx0(0)*sy(1)*sz(1)*wqx
    jx(j0+1, k+1, l+1)    = jx(j0+1, k+1, l+1)  +   sx0(1)*sy(1)*sz(1)*wqx

    ! - JY
    jy(j, k0, l  )    = jy(j, k0, l  )  +   sx(0)*sy0(0)*sz(0)*wqy
    jy(j+1, k0, l  )    = jy(j+1, k0, l  )  +   sx(1)*sy0(0)*sz(0)*wqy
    jy(j, k0+1, l  )    = jy(j, k0+1, l  )  +   sx(0)*sy0(1)*sz(0)*wqy
    jy(j+1, k0+1, l  )    = jy(j+1, k0+1, l  )  +   sx(1)*sy0(1)*sz(0)*wqy
    jy(j, k0, l+1)    = jy(j, k0, l+1)  +   sx(0)*sy0(0)*sz(1)*wqy
    jy(j+1, k0, l+1)    = jy(j+1, k0, l+1)  +   sx(1)*sy0(0)*sz(1)*wqy
    jy(j, k0+1, l+1)    = jy(j, k0+1, l+1)  +   sx(0)*sy0(1)*sz(1)*wqy
    jy(j+1, k0+1, l+1)    = jy(j+1, k0+1, l+1)  +   sx(1)*sy0(1)*sz(1)*wqy

    ! - JZ
    jz(j, k, l0  )    = jz(j, k, l0  )  +   sx(0)*sy(0)*sz0(0)*wqz
    jz(j+1, k, l0  )    = jz(j+1, k, l0  )  +   sx(1)*sy(0)*sz0(0)*wqz
    jz(j, k+1, l0  )    = jz(j, k+1, l0  )  +   sx(0)*sy(1)*sz0(0)*wqz
    jz(j+1, k+1, l0  )    = jz(j+1, k+1, l0  )  +   sx(1)*sy(1)*sz0(0)*wqz
    jz(j, k, l0+1)    = jz(j, k, l0+1)  +   sx(0)*sy(0)*sz0(1)*wqz
    jz(j+1, k, l0+1)    = jz(j+1, k, l0+1)  +   sx(1)*sy(0)*sz0(1)*wqz
    jz(j, k+1, l0+1)    = jz(j, k+1, l0+1)  +   sx(0)*sy(1)*sz0(1)*wqz
    jz(j+1, k+1, l0+1)    = jz(j+1, k+1, l0+1)  +   sx(1)*sy(1)*sz0(1)*wqz
  END DO
  RETURN
END SUBROUTINE depose_jxjyjz_scalar_1_1_1
