program mtc_main
    use, intrinsic :: iso_fortran_env, only : real64
    use :: mtc_config_module, only : mtc_config
    use :: mtc_patch_module, only : mtc_patch
    use :: cmdline_arguments_module, only : cmdline_arguments
    use :: mtc_module, only : mtc

    implicit none

    type(mtc_config) :: config
    real(real64), dimension(:,:,:,:,:,:), allocatable :: t3
    real(real64), dimension(:,:,:), allocatable :: v, t2, f
    type(mtc_patch) :: p
    type(mtc) :: anmtc
    integer :: bra, ket
    real(real64) :: memory

    config = mtc_config(cmdline_arguments(4))
    p = config%create_patch()
    call p%dump(.false.)

    memory = real(config%number_of_blocks**2, real64)*p%nab*p%nc*p%nij*p%nk
    memory = memory + real(p%nab, real64)*p%np*p%nh
    memory = memory + p%np*p%np*p%nij
    memory = memory + p%nc*p%nk*p%np
    memory = memory*8

    write(*,'(a,f10.3,a)') "Memory usage: ", memory/1024/1024/1024, " Gb"
    if (config%run) then
        write(*,*) "Running contractions..."
        allocate(t3(p%nab, p%nc, p%nij, p%nk, config%number_of_blocks, config%number_of_blocks))
        allocate(v(p%nab, p%np, p%nh))
        allocate(t2(p%np, p%np, p%nij))
        allocate(f(p%nk, p%np, p%nc))
        call random_number(t3)
        call random_number(v)
        call random_number(t2)
        call random_number(f)

        do ket = 1, config%number_of_blocks
            do bra = 1, config%number_of_blocks
                call anmtc%contract(t2, t3(:,:,:,:,bra, ket), v, f, p)
            end do
        end do
    end if
end program mtc_main
