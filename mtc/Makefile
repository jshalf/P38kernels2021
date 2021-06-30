objects = string.o string_converter.o cmdline_arguments.o mtc_patch.o mtc_config.o mtc.o mtc_main.o

all: ${objects}
	${XLF} -o mtc.x ${objects}

%.o: %.f90
	${XLF} -c $<

.PHONY. : clean
clean:
	rm *.o *.mod mtc.x