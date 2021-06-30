module mtc_module
    use, intrinsic :: iso_fortran_env, only : real64
    use :: mtc_patch_module, only : mtc_patch

    implicit none
    private

    public :: mtc

    type :: mtc
    contains
        procedure :: contract => contract
        procedure :: cleanup => cleanup
        procedure :: clear => clear
    end type mtc

    interface mtc
        module procedure constructor
    end interface mtc

contains
    function constructor() result(this)
        type(mtc) :: this

        call this%clear()
    end function constructor

    subroutine contract(this, t2, t3, v, f, p)
        class(mtc), intent(in) :: this
        real(real64), dimension(:,:,:), intent(inout) :: t2
        real(real64), dimension(:,:,:,:), intent(in) :: t3
        real(real64), dimension(:,:,:), intent(in) :: v, f
        type(mtc_patch), intent(in) :: p

        real(real64) :: temp1, temp2
        integer :: ij, bidx, b, a, midx, m, ef

        do ij = 1, p%nij
            do bidx = 1, p%nc
                b = p%cmap(bidx)
                do a = 1, p%np
                    temp1 = 0.0d0
                    do midx = 1, p%nk
                        m = p%kmap(midx)
                        temp2 = 0.0d0
                        do ef = 1, p%nab
                            temp2 = temp2+ t3(ef, bidx, ij, midx)*v(ef, a, m)
                        end do
                        temp1 = temp1 + temp2*f(midx, a, bidx)
                    end do
                    t2(a, b, ij) = t2(a, b, ij) + temp1
                end do
            end do
        end do
    end subroutine contract

    subroutine cleanup(this)
        class(mtc), intent(inout) :: this

        call this%clear()
    end subroutine cleanup

    subroutine clear(this)
        class(mtc), intent(inout) :: this
    end subroutine clear
end module mtc_module
