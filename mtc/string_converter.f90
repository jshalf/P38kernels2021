module string_converter_module
    use, intrinsic :: iso_fortran_env, only : error_unit
    use :: string_module, only : string
    implicit none
    private

    public :: string_converter

    type :: string_converter
    contains
        procedure, nopass :: toint => toint
        procedure, nopass :: toreal32 => toreal32
    end type string_converter
contains
    integer function toint(str)
        type(string), intent(in) :: str

        integer :: error

        read(str%char_array, *, iostat=error) toint
        if ( error /= 0) then
            write(error_unit, *) &
                    "string_converter::Error converting string to integer"
            stop
        end if
    end function toint

    real function toreal32(str)
        type(string), intent(in) :: str

        integer :: error

        read(str%char_array, *, iostat=error) toreal32
        if ( error /= 0) then
            write(error_unit, *) &
                    "string_converter::Error converting string to real32"
            stop
        end if
    end function toreal32
end module string_converter_module
