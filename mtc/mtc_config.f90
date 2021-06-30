module mtc_config_module
    use :: cmdline_arguments_module, only : cmdline_arguments
    use :: string_converter_module, only : string_converter
    use :: mtc_patch_module, only : mtc_patch
    use :: string_module, only : string

    implicit none
    private

    public :: mtc_config

    type :: mtc_config
        integer :: number_of_particles, basis_size, number_of_blocks
        real :: nonzero_fraction
        logical :: run
    contains
        procedure :: create_patch => create_patch
        procedure, nopass :: get_mask => get_mask
        procedure :: cleanup => cleanup
        procedure :: clear => clear
    end type mtc_config

    interface mtc_config
        module procedure constructor_empty
        module procedure constructor
    end interface mtc_config

contains
    function constructor_empty() result(this)
        type(mtc_config) :: this

        call this%clear()
    end function constructor_empty

    function constructor(cmd) result(this)
        type(cmdline_arguments), intent(in) :: cmd
        type(mtc_config) :: this

        type(string_converter) :: converter
        type(string) :: dummy

        this = mtc_config()

        this%number_of_particles = converter%toint(cmd%get_argument(1))
        this%basis_size = converter%toint(cmd%get_argument(2))
        this%number_of_blocks = converter%toint(cmd%get_argument(3))
        this%nonzero_fraction = converter%toreal32(cmd%get_argument(4))

        if ( cmd%number_of_arguments > 4 ) then
            dummy = cmd%get_argument(5)
            if (dummy == "no") this%run = .false.
        end if
    end function constructor

    type(mtc_patch) function create_patch(this)
        class(mtc_config), intent(in) :: this

        integer :: nh, np, nc, nab, nk, nij, idx
        integer, dimension(:), allocatable :: cmap, kmap
        logical, dimension(:), allocatable :: mask

        nh = this%number_of_particles
        np = this%basis_size - this%number_of_particles

        nc = max(1, ceiling(this%nonzero_fraction*np))
        nab = nc**2
        nk = max(1, ceiling(this%nonzero_fraction*nh))
        nij = nk**2

        mask = this%get_mask(nk, nh)
        kmap = pack([(idx, idx = 1, nh)], mask)

        mask = this%get_mask(nc, np)
        cmap = pack([(idx, idx = 1, np)], mask)
        create_patch = mtc_patch(nh, np, nab, nc, nij, nk, cmap, kmap)
    end function create_patch

    function get_mask(nsmall, nlarge) result(mask)
        integer, intent(in) :: nsmall, nlarge
        logical, dimension(:), allocatable :: mask

        integer :: counter, idx
        real :: rnd
        logical :: more

        allocate(mask(nlarge))
        mask = .false.

        more = .true.
        counter = 0
        do while ( more )
            call random_number(rnd)
            idx = ceiling(rnd*nlarge)
            if ( mask(idx) ) cycle

            mask(idx) = .true.
            counter = counter + 1
            more = counter < nsmall
        end do
    end function get_mask

    subroutine cleanup(this)
        class(mtc_config), intent(inout) :: this

        call this%clear()
    end subroutine cleanup

    subroutine clear(this)
        class(mtc_config), intent(inout) :: this

        this%number_of_particles = 0
        this%basis_size = 0
        this%number_of_blocks = 0
        this%nonzero_fraction = 1.0
        this%run = .true.
    end subroutine clear
end module mtc_config_module
