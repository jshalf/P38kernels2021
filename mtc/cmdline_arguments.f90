module cmdline_arguments_module
    use, intrinsic :: iso_fortran_env, only : error_unit
    use :: string_module, only : string
    implicit none
    private

    public :: cmdline_arguments

    type :: cmdline_arguments
        integer :: number_of_arguments
        type(string), dimension(:), allocatable :: arguments
    contains
        procedure :: get_argument => get_argument
        procedure :: cleanup => cleanup
        procedure :: clear => clear
    end type cmdline_arguments

    interface cmdline_arguments
        module procedure constructor
    end interface cmdline_arguments

contains
    function constructor(min_num_args) result(this)
        integer, intent(in), optional :: min_num_args
        type(cmdline_arguments) :: this

        character(len=100) :: dummy
        integer :: idx, minimum_number_of_arguments

        call this%clear()

        minimum_number_of_arguments = 0
        if (present(min_num_args)) minimum_number_of_arguments = min_num_args
        this%number_of_arguments = command_argument_count()

        if (this%number_of_arguments < minimum_number_of_arguments) then
            write(error_unit, *) "Not enough command line arguments."
            write(error_unit, *) "Number of given arguments: ", this%number_of_arguments
            write(error_unit, *) "Minimum number of arguments: ", minimum_number_of_arguments
            stop
        end if

        allocate(this%arguments(this%number_of_arguments))
        do idx = 1, this%number_of_arguments
            call get_command_argument(idx, dummy)
            this%arguments(idx) = trim(adjustl(dummy))
        end do
    end function constructor

    type(string) function get_argument(this, idx)
        class(cmdline_arguments), intent(in) :: this
        integer, intent(in) :: idx

        get_argument = this%arguments(idx)
    end function get_argument

    subroutine cleanup(this)
        class(cmdline_arguments), intent(inout) :: this

        integer :: idx

        if (allocated(this%arguments)) then
            do idx = 1, size(this%arguments)
                call this%arguments(idx)%cleanup()
            end do
            deallocate(this%arguments)
        end if
        call this%clear()
    end subroutine cleanup

    subroutine clear(this)
        class(cmdline_arguments), intent(inout) :: this

        this%number_of_arguments = 0
    end subroutine clear
end module cmdline_arguments_module
