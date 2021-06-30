CC=icc
CFLAGS= ${xflags} -std=c++11 -O3 -xcore-avx2 -g -I. -L/soft/compilers/intel/vtune_amplifier_2018.1.0.535340/lib64 -I/soft/compilers/intel/vtune_amplifier_2018.1.0.535340/include -I${MKLROOT}/include/fftw/ -L${MKLROOT}/lib/intel64 -lmkl_intel_ilp64 -lmkl_intel_thread -lmkl_core -liomp5 -lpthread -lm -ldl -littnotify -DMKL_ILP64 -qopenmp


ODIR=obj
_OBJ = com-oop-hsw-benchfft.o
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))


$(ODIR)/%.o: %.cpp
	$(CC) -c -o $@ $< $(CFLAGS) 

com-oop-hsw-benchfft: $(OBJ)
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS)

.PHONY: clean

clean:
	rm -f $(ODIR)/*.o *~ core 
