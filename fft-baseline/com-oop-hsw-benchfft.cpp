#include <fftw3.h>
#include <iostream>
#include <assert.h>
#include <stdlib.h>
#include <random>
#include <omp.h>
#include <limits.h>
#include <ittnotify.h>
#include <time.h>

long nsecClock()
{
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return 1e+9*ts.tv_sec+ts.tv_nsec;
}

int main(int argc, char** argv)
{
  fftwf_init_threads();
  fftwf_plan_with_nthreads(omp_get_max_threads());
  
  assert(argc == 2);
  auto n = strtoull(argv[1], NULL, 10);

  fftwf_complex *in;
  fftwf_complex *out;
  fftwf_plan p;

  in = (fftwf_complex*)fftwf_malloc(sizeof(fftwf_complex)*n);
  out = (fftwf_complex*)fftwf_malloc(sizeof(fftwf_complex)*n);

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_real_distribution<float> dist(0.0f, 1.0f);

#pragma omp parallel for
  for (size_t i=0; i<n; ++i) {
    in[i][0] =  dist(gen);
    in[i][1] =  0.0f;
    out[i][0] =  0.0f;
    out[i][1] =  0.0f;
  }
  int rank=1;
  fftwf_iodim64* dims = (fftwf_iodim64*)fftwf_malloc(rank*sizeof(fftwf_iodim64));
  dims[0].n=n;
  dims[0].is=1;
  dims[0].os=1;

  int howmany_rank=1;
  fftwf_iodim64* howmany_dims = (fftwf_iodim64*)fftwf_malloc(howmany_rank*sizeof(fftwf_iodim64));
  howmany_dims[0].n=1;
  howmany_dims[0].is=1;
  howmany_dims[0].os=1;


  //Create plan for out-of-place complex transform			     
  p = fftwf_plan_guru64_dft(rank, dims, howmany_rank, howmany_dims, in, out, FFTW_FORWARD, FFTW_MEASURE);

  long time0;
  long time1;
  double flops;

  //Warmup cache
  for(int i=0; i<10; i++)
    {
              time0 = nsecClock();
  fftwf_execute(p);
      time1 = nsecClock() - time0;
        flops = 5.0*n*log2(n);
	//        std::cout << flops/time1 << std::endl;
    }



#ifdef sde
  __SSC_MARK(0x111);
#endif
#ifdef vtune
  __itt_resume();
#endif

  fftwf_execute(p); 

#ifdef vtune
  __itt_pause();
#endif
#ifdef sde
  __SSC_MARK(0x222);
#endif


  fftwf_destroy_plan(p);
  fftwf_free(in);
  fftwf_free(out);
  fftwf_cleanup_threads();

  return 0;
}
