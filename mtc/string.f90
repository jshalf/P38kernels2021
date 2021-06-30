module string_module
    implicit none
    private

    public :: string
    public :: split_string_word

    type :: string
        character(len=:), allocatable :: char_array
        integer :: length
    contains
        generic, public :: init => init_char_array, init_string
        generic, public :: assignment (=) => assign_string, assign_char_array
        generic, public :: operator (.eq.) => equality_string, equality_char_array
        generic, public :: cat => cat_char_array, cat_string

        procedure, public :: cleanup => cleanup
        procedure, public :: as_char_array => as_char_array
        procedure, public :: split => split
        procedure, public :: cat_string
        procedure, public :: cat_char_array
        procedure, public :: strip => strip

        ! private routines that are called through generic interface
        procedure, private :: init_char_array
        procedure, private :: init_string
        procedure, private :: assign_string
        procedure, private :: assign_char_array
        procedure, private :: equality_string
        procedure, private :: equality_char_array
    end type string

    interface string
        module procedure string_factory
    end interface string
contains

    pure function string_factory(char_array, strip) result(astring)
        character(len=*), intent(in) :: char_array
        logical, intent(in), optional :: strip
        type(string) :: astring

        logical :: strip_input

        strip_input = .false.
        if (present(strip)) strip_input = strip
        if (strip_input) then
            astring = trim(adjustl(char_array))
        else
            astring = char_array
        end if
    end function string_factory

    pure subroutine init_char_array(this, char_array)
        class(string), intent(inout) :: this
        character(len=*), intent(in) :: char_array

        integer :: length

        call this%cleanup()

        length = len(char_array)
        this%char_array = char_array
        this%length = length
    end subroutine init_char_array

    function as_char_array(this) result(char_array)
        class(string), intent(in) :: this
        character(len=:), allocatable :: char_array

        char_array = this%char_array
    end function as_char_array
        
    pure subroutine init_string(this, str)
        class(string), intent(inout) :: this
        type(string), intent(in) :: str

        if (allocated(str%char_array)) then
            call init_char_array(this, str%char_array)
        else
            call this%cleanup()
        endif
    end subroutine init_string

    function strip(this) result(stripped)
        class(string), intent(in) :: this
        type(string) :: stripped

        stripped = trim(adjustl(this%char_array))
    end function strip

    function cat_char_array(this, other) result(res)
        class(string) :: this
        character(len=*), intent(in) :: other
        type(string) :: res

        if (allocated(this%char_array)) then
            res = this%char_array//other
        else
            res = other
        endif

    end function cat_char_array

    function cat_string(this, other) result(res)
        class(string) :: this
        type(string), intent(in) :: other
        type(string) :: res


        if (allocated(this%char_array) .and. allocated(other%char_array)) then
            res = this%char_array//other%char_array
        else if (allocated(this%char_array)) then
            res = this%char_array
        else if (allocated(other%char_array)) then
            res = other%char_array
        else
            call res%cleanup()
        endif

    end function cat_string

    pure subroutine assign_string(this, other)
        class(string), intent(inout) :: this
        type(string), intent(in) :: other

        call this%init_string(other)
    end subroutine assign_string

    pure subroutine assign_char_array(this, other)
        class(string), intent(inout) :: this
        character(len=*), intent(in) :: other

        call this%init_char_array(other)
    end subroutine assign_char_array

    pure function equality_string(this, other) result(res)
        class(string), intent(in) :: this
        type(string), intent(in) :: other
        logical :: res

        res = .true.
        if (allocated(this%char_array) .and. allocated(other%char_array)) then
            if (this%char_array /= other%char_array) res = .false.
        else
            if (allocated(this%char_array) .or. allocated(other%char_array)) res = .false.
        endif
    end function equality_string

    pure function equality_char_array(this, other) result(res)
        class(string), intent(in) :: this
        character(len=*), intent(in) :: other
        logical :: res

        res = .true.
        if (allocated(this%char_array) ) then
            if (this%char_array /= adjustl(trim(other))) res = .false.
        else
            if (len(trim(adjustl(other))) /= 0) res = .false.
        endif
    end function equality_char_array

    pure subroutine cleanup(this)
        class(string), intent(inout) :: this

        if (allocated(this%char_array)) deallocate(this%char_array)
        this%length = 0
    end subroutine cleanup

    function split(this, delimiter) result(word)
      class(string) :: this
      character :: delimiter
      type(string), dimension(:), allocatable :: word
      integer :: pos1, pos2, n, max_length
      character(len=:), allocatable :: text
     
      max_length = 0
      pos1 = 1
      n = 0

      if (.not. allocated(this%char_array)) return

      ! workaround for gfortran bug (br 63494)
      text = this%char_array

      ! count and determine maximum length
      do
        pos2 = index(text(pos1:), delimiter)
        if (pos2 == 0) then
           pos2 = len(text) + 1
           n = n + 1
           if (max_length < pos2-pos1) max_length = pos2-pos1
           exit
        end if
        n = n + 1
        if (max_length < pos2-pos1) max_length = pos2-pos1
        pos1 = pos2+pos1
     end do

        allocate(word(n))


      pos1 = 1
      n = 0
      do
        pos2 = index(text(pos1:), delimiter)
        if (pos2 == 0) then
           n = n + 1
           word(n) = text(pos1:)
           exit
        end if
        n = n + 1
        word(n) = text(pos1:pos1+pos2-2)
        pos1 = pos2+pos1
     end do
    end function split

    subroutine split_string_word(str, delimiter, word)
      character(len=*) :: str
      character :: delimiter
      character(len=100), allocatable, intent(inout) :: word(:)
      integer :: pos1, pos2, n, max_length
     
      max_length = 0
      pos1 = 1
      n = 0


      ! count and determine maximum length
      do
        pos2 = index(str(pos1:), delimiter)
        if (pos2 == 0) then
           pos2 = len(str) + 1
           n = n + 1
           if (max_length < pos2-pos1) max_length = pos2-pos1
           exit
        end if
        n = n + 1
        if (max_length < pos2-pos1) max_length = pos2-pos1
        pos1 = pos2+pos1
     end do

        allocate(word(n))


      pos1 = 1
      n = 0
      do
        pos2 = index(str(pos1:), delimiter)
        if (pos2 == 0) then
           n = n + 1
           word(n) = str(pos1:)
           exit
        end if
        n = n + 1
        word(n) = str(pos1:pos1+pos2-2)
        pos1 = pos2+pos1
     end do

    end subroutine split_string_word

end module string_module
