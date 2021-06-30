______________________________________________________________________________

    HipMer v 1.0, Copyright (c) 2016, The Regents of the University of California,
    through Lawrence Berkeley National Laboratory (subject to receipt of any
    required approvals from the U.S. Dept. of Energy).  All rights reserved.
 
    If you have questions about your rights to use or distribute this software,
    please contact Berkeley Lab's Innovation & Partnerships Office at  IPO@lbl.gov.
 
    NOTICE.  This Software was developed under funding from the U.S. Department
    of Energy and the U.S. Government consequently retains certain rights. As such,
    the U.S. Government has been granted for itself and others acting on its behalf
    a paid-up, nonexclusive, irrevocable, worldwide license in the Software to
    reproduce, distribute copies to the public, prepare derivative works, and
    perform publicly and display publicly, and to permit other to do so. 

______________________________________________________________________________

# *HipMer* -- High Performance Meraculous


>HipMer is a high performance, distributed memory and scalable version of [Meraculous](http://jgi.doe.gov/data-and-tools/meraculous/), a de novo genome assembler.
>
>It is largely written in UPC, with the exception of the UFX generation, which is written in C++/MPI.
>
> This project is a joint collaboration between [JGI](http://jgi.doe.gov), 
> [NERSC](http://www.nersc.gov/) and [CRD](http://crd.lbl.gov/)
>
> Primary authors are:
> Evangelos Georganas, Aydın Buluç, Steven Hofmeyr and Rob Egan, 
> with direction and advice from Kathy Yelick and Leonid Oliker.
>
> The original Meraculous was developed by Jarrod Chapman, Isaac Ho, Eugene Goltsman,
> and Daniel Rokhsar.

### Related Publications

* Evangelos Georganas, Aydın Buluç, Jarrod Chapman, Steven Hofmeyr, Chaitanya Aluru, Rob Egan, Leonid Oliker, Daniel Rokhsar and Katherine Yelick, ["HipMer: An Extreme-Scale De Novo Genome Assembler"](http://www.eecs.berkeley.edu/~egeor/sc15_genome.pdf). 27th ACM/IEEE International Conference on High Performance Computing, Networking, Storage and Analysis (SC 2015), Austin, TX, USA, November 2015.

* Evangelos Georganas, Aydın Buluç, Jarrod Chapman, Leonid Oliker, Daniel Rokhsar and Katherine Yelick, ["merAligner: A Fully Parallel Sequence Aligner"](http://www.eecs.berkeley.edu/~egeor/ipdps_genome.pdf). 29th IEEE International Parallel & Distributed Processing Symposium (IPDPS 2015), Hyderabad, INDIA, May 2015.

* Jarrod A Chapman, Martin Mascher, Aydın Buluç, Kerrie Barry, Evangelos Georganas, Adam Session, Veronika Strnadova, Jerry Jenkins, Sunish Sehgal, Leonid Oliker, Jeremy Schmutz, Katherine A Yelick, Uwe Scholz, Robbie Waugh, Jesse A Poland, Gary J Muehlbauer, Nils Stein and Daniel S Rokhsar ["A whole-genome shotgun approach for assembling and anchoring the hexaploid bread wheat genome"](http://genomebiology.biomedcentral.com/articles/10.1186/s13059-015-0582-8) . Genome Biology 2015, 16:26 .

* Evangelos Georganas, Aydın Buluç, Jarrod Chapman, Leonid Oliker, Daniel Rokhsar and Katherine Yelick, ["Parallel De Bruijn Graph Construction and Traversal for De Novo Genome Assembly"](http://www.eecs.berkeley.edu/~egeor/sc14_genome.pdf). 26th ACM/IEEE International Conference on High Performance Computing, Networking, Storage and Analysis (SC 2014), New Orleans, LA, USA, November 2014.

-----------------------
## Building and installing

HipMer can run on compute platforms of any size and scale from the largest Cray supercomputers like
those hosted at [NERSC](https://www.nersc.gov) to smaller linux clusters (with low latency networks)
and also on *any* single Linux or MacOSX computer or laptop.  The only requirement is a properly
configured set of compilers for your platform.

### Requirements

1. Working [Message Passing Interface - MPI](https://en.wikipedia.org/wiki/Message_Passing_Interface) Environment
    1. [Open MPI](https://www.open-mpi.org)
    2. [MPICH2](http://www.mcs.anl.gov/project/mpich-high-performance-portable-implementation-mpi)
2. Working [Unified Parallel C - UPC](https://en.wikipedia.org/wiki/Unified_Parallel_C) Environment
    1. [Berkeley UPC >= 2.20.0](http://upc.lbl.gov)
    2. see contrib/install_upc.sh for a simplified install (recommend mpi conduit)
        1. mpi conduit should simply work but may be slower
3. Working C/C++ compiler
    1. Intel >= 15.0.1.133
    2. GCC >= 4.8
    3. CLang >= 700.1.81

See README-MacOSX.md for instructions on how to prepare the compilers for 
a Mac running OS X 10.10.5

### Download HipMer

Anyone can download the source from sourceforge: https://sourceforge.net/projects/hipmer/

Or, if you have access, clone the source from bitbucket.org: https://bitbucket.org/berkeleylab/hipmeraculous 


### Building

To build, install and run test cases, simple configurations (standard Linux distros) no configuration
should be necessary.

For more complex hardware (like HPC clusters), check the env scripts from the appropriate 
.platform_deploy, where 'platform' is one of several different platforms, e.g. 
'.edison_deploy' for NERSC's Edison system, '.cori_deploy' for NERSC's cori 
system, '.genepool_deploy' for JGI's inifinband cluster, '.lawrencium_deploy' for LBL's 
inifiband cluster and finally '.generic_deploy' for a generic Linux system.

Then copy, modify and/or link the appropriate env.sh script to the top-level source directory (this dir)
as hipmer_env.sh.  See hipmer_env.sh-EXAMPLE for a comprehensive list of variables that can (optionally)
be specified

This will be your machine-specific environment script and it will be installed and then used whenever
HipMer executes.

Alternatively to making a hipmer_env.sh script in the top level source dirctory, you can export the path
to the HIPMER_ENV_SCRIPT variable or put it into your environment or as an ENV=val command line
argument to several of the scripts (i.e. run_hipmer.sh, test_hipmer.sh, and bootstrap_hipmer_env.sh):

   export HIPMER_ENV_SCRIPT=path/to/env.sh

Then execute the bootstrap build/install script:

   ./bootstrap_hipmer_env.sh [HIPMER_ENV_SCRIPT=/path/to/hipmer_env.sh]  [build|install]

Within the HIPMER_ENV_SCRIPT you can should specify the environmental variable SCRATCH for default placement 
of the build and install paths. You can also change the default build and install 
paths by overriding the environmental variables HIPMER_BUILD and HIPMER_INSTALL variables


To build and install:

    ./bootstrap_hipmer_env.sh install

To only perform the build:

    ./bootstrap_hipmer_env.sh build


By default, the build will be in $HIPMER_BUILD or $SCRATCH/${USER}-hipmer-build-${HIPMER_ENV} and the install will 
be in $HIPMER_INSTALL $SCRATCH/hipmer-install-${HIPMER_ENV}

You should then be able to executue the hipmer pipeline by specifying the fully-qualified path to 
run_hipmer.sh.  ($HIPMER_INSTALL/bin/run_hipmer.sh config)

There are environmental variables that are automatically set for a release 
(non-debug) build (.platform_deploy/env.sh). To build a debug version, set 
HIPMER_BUILD_TYPE=Debug in the HIPMER_ENV_SCRIPT used to build and install.

Examples can be found at .*_deploy/*-debug.sh

Then install with the bootstrap_hipmer_env.sh script

To force a complete rebuild:

    CLEAN=1 ./bootstrap_hipmer_env.sh install

To force a rebuild with all the environment checks:

    DIST_CLEAN=1 ./bootstrap_hipmer_env.sh install

Note that running ./bootstrap_hipmer_env.sh install should do partial rebuilds for 
changed files.

WARNING: the build process does not detect header file dependencies for UPC 
automatically, so changes to header files will not necessarily trigger 
rebuilds. The dependencies need to be manually added. This has been done for 
some, but not all, stages. So if any code gets changed in a header file, it is recommended to
build with CLEAN=1.

Some features of the cmake build process:

  * Builds multiple binaries based on the build parameters:
  export HIPMER_BUILD_OPTS="-DHIPMER_KMER_LENGTHS='32; 64'" 
  (HIPMER_KMER_LENGTHS need to be in multiples of 32)
  * Properly builds UPC source (if you name the source .upc or set the LANGUAGE and LINKER_LANGUAGE
  property to UPC)  
  * Sets the -D definition flags consistently 
  * Supports -DCMAKE_BUILD_TYPE=Release or Debug

Some special environment variables (advanced):

  * HIPMER_UPC_ALLOCATOR=1 (Default is unset. When set to 1 it makes the ufx stage use UPC shared
    memory in the single executable)
  * HIPMER_FULL_BUILD=0 (Default is 1. When set to 1, builds a separate executable for each stage,
    and runs them separately. When set to 0, builds a single executable incorporating all the
    stages.)

-------
## Troubleshooting

Some people had seen the following error during build: 

    make: *** No rule to make target REPLACE_VERSION_H.  Stop.

That's a cmake target that gets executed before the rest of the pipeline and we think that if the
build directory was only partially configured, then cmake forgets to properly prepare that target
the next time around. Try executing:

    DIST_CLEAN=1 ./bootstrap_hipmer_env.sh install


-------
## Running

Each stage can be run individually, using upcrun or mpirun. To run the full pipeline, use the
src/hipmer/run_hipmer_unified.sh script (we also provide convenience scripts for several datasets
that call the run script. Often it is easiest to modify these instead of calling
run_hipmer_unified.sh directly). Note that run_hipmer.sh will record the full trace of the output in
the run directory under the name run.out.

The run script (run_hipmer_unified.sh) expects as a parameter the name of a configuration
file. Examples of configuration files are given in test/pipeline/*.config. Various options to the
run script can be set as environment variables:

    THREADS=X 
      Total number of UPC threads. This is *required*.

    CORES_PER_NODE=X
      The number of cores per node. If not set, it will be determined by inspecting the
      /proc/cpuinfo file, ignoring hyperthreads.

    KMER_CACHE_MB=X 
    SW_CACHE_MB=X 
      The size size of the kmer and software caches, in MB. These are used during the 
      alignment stage. Larger caches can speed up alignment. If not set, these are 
      automatically determined based on available memory. 

    ILLUMINA_VERSION=X 
      The Illumina version for the FASTQ files, used to determine how to interpret the 
      quality scores. If not set, it will be estimated from the first FASTQ file.

    DRYRUN=1 
      Do a dryrun, i.e. show all the stages that would run but do not execute them.

    DEBUG=1 
      Output a lot of debugging information. 

    CACHED_IO=1
      Cache intermediate files in memory. This can greatly speedup execution by reducing 
      disk IO. However more memory will be required and it also means that runs cannot be 
      resumed at a given point after a failure. Defaults to on.

    UPC_SHARED_HEAP_SIZE=X 
      Set the per thread size of the UPC shared heap. See the upcrun documentation for 
      more information about this option. If not set it will be set to a reasonable 
      default (60% of the available memory without cached IO, 30% when using cached IO). 
      Do not make this too large because the first stage (UFX) is written in MPI and does 
      not use the UPC shared heap, and UFX needs a reasonable amount of memory to run.

    CANONICALIZE=1
      Sort the final assembly into a canonical form. Useful for validation but expensive 
      for large scale runs. Defaults to off.
    
For convenience, there is a script src/hipmer/test_hipmer.sh that sets up and executes a run on a few
standard datasets. It creates an unique output directory ($RUNDIR) in $SCRATCH, copies the config file
into that directory, links all data files into the directory, and executes the run script.  This script
will properly bootstrap if called with the fully qualified path.

   ${HIPMER_INSTALL}/bin/test_hipmer.sh [validation|ecoli|chr14|human|metagenome]

To see examples of how the test_hipmer.sh script is used, look at the test_*.sh scripts in
test/hipmer. Each of these scripts determines the machine on which it is being run (generic Linux,
NERSC Edison or NERSC Cori), and then passes the correct parameters to test_hipmer.sh These scripts are
configured so that they can be submitted to job queues on Cori or Edison (SLURM scheduler), or run
directly on generic Linux. The scripts are:

test_validation.sh
  A small validation run. It runs in 10s of seconds on a single note, and includes checking of the
  assembly at the end to determine if it is correct.

test_ecoli.sh
  The ecoli dataset. Small enough to run on a single node and should complete in a few
  minutes. Checking of the results is also performed, although the assembly result could differ
  slightly from the default due to the non-deterministic nature of the algorithms.

test_chr14.sh
  The human chromosome 14. This may be too large to run on a single node, unless it has at least 128G of 
  memory. It will take tens of minutes.

test_human.sh
  The full human dataset. This is likely too large to run on a single node, unless it has at least 1TB of 
  memory. It will take several hours on a large-memory single node.

test_metagenome.sh
  A simple test for assembling metagenomes using the metagenome pipeline. This will run on a single
  node and should take under 10 minutes. This script can also be used for running other, larger
  metagenome data sets within the same data directory by setting the environment variable
  HIPMER_TEST to the chosen config file.

The data for these can be setup using the scripts test/hipmer/hipmer_setup_*_data.sh.

Often the easiest way to set up a new run will be to simply use a modified version of one of the
test_*.sh scripts.

--------
## Rerunning stages

Once a run has completed, specific stages can be rerun from within the run directory. The call will
be something like (e.g. for the ecoli test case):

upcrun -n 48 -shared-heap=800M main-32 -f ecoli.config -s <stages_to_rerun>

where "stages_to_rerun" is a comma separated list of stage names, or the words "all" or
"scaffolding". To determine the names for specific stages, look at the end of the output for the
full run. You should see a list of timings, something like:

```
########################################################################
# Completed 13 stages in 68.17 s on 48 threads over 1 nodes:
#    STAGE                                       time (s)   leaked mem (gb/node)
#    ufx-21                                     30.23       3.8
#    meraculous-21                               0.58       0.0
#    contigMerDepth-21                           0.26       0.0
#    canonical_assembly-contigs                  0.10       0.0
#    merAligner-ECO-21                          28.68       1.4
#    splinter-ECO                                0.47       0.0
#    merAlignerAnalyzer-ECO-21                   0.10      -0.0
#    spanner-ECO                                 0.82       0.0
#    bmaToLinks-1                                0.18       0.0
#    oNo-1                                       0.03       0.0
#    gapclosing                                  6.59       0.0
#    canonical_assembly                          0.13       0.0
#    canonical_assembly-1000                     0.01       0.0
# Overall time for main-32 is 68.37 s
########################################################################
```

The names for the stages are under the STAGE column. So, for example, to rerun just ufx and
meraculous, you would execute:

upcrun -n 48 -shared-heap=800M main-32 -f ecoli.config -s ufx-21,meraculous-21

If you do not have the output from the previous run and want to determine the stage names, do a
dryrun from within the run directory, e.g.

DRYRUN=1 upcrun -n 48 main-32 -f ecoli.config 

You can also restart an aborted pipeline by specifying the name of the stage that failed, followed
by "-end". This will rerun the failed stage, followed by the rest of the pipeline. Do not specify
any other stages in this case. This can also be used to restart a previously completed pipeline at
any stage.

You can also specify that the pipeline should automatically restart after a failure by setting the
environment variable AUTORESTART=1. That will cause the pipeline to restart in the same run
directory, at the beginning of the failed stage. If the same stage fails again, it will abort so as
not to get in an infinite loop. The purpose of this feature is to enable restarts when running out
of memory - there are still some memory leaks so that over the duration of a run, memory gets used
up.

--------
## Saving memory

There are two ways to reduce the memory use of the pipeline. The first is to run it with each stage as a separate executable, i.e. build with HIPMER_FULL_BUILD=1. This will result in a much slower execution, however, because of the UPC and MPI launch overheads for each stage. An alternative is to force a restart after each UFX stage, which will free the memory reserved by MPI after each execution of UFX. To force this targeted restart, use the environment variable AUTORESTART_UFX=1.

If oNo aborts with insufficient memory, you probably need to reduce the ono_pair_thresholds in the config file. Fewer thresholds means more memory available for each threshold calculation.

If you get a SIGBUS error, this is almost certainly caused by insufficient memory. This is most likely to happen if you are using upc compiled with posix shared memory (the default). On Linux, posix shared memory is backed by /run/shm, which by default is limited to a maximum of 50% of the total memory. If this is a problem, you can increase the memory available to /run/shm by adding the following line to /etc/fstab

```
  none  /run/shm  tmpfs  nosuid,nodev,size=80%  0 0
```

and then remounting the virtual file system:

```
mount -o remount /run/shm
```

--------
## Diagnostics and comparing outputs

The pipeline produces a file called diags.log that records a number of results from each stage as
key-value pairs. Multiple runs can be compared with the script compare_diags.py, included in the bin
install directory. The script compares each key-value pair for name mismatches and checks to see if
the value lies within a specified threshold, and reports keys that don't. For checking, diagnostics
outputs are provided for the standard tests with chr14 and the small metagenome. Those files are in
test/pipeline and are called chr14.diags and metagenome.diags, respectively.

--------
## Workflow

The HipMer workflow is controlled within the configuration file, when the 
libraries are specified. For each library, you can specify what round of oNo to 
use it in, and you can specify whether or not to use it for splinting. The 
workflow is as follows (see run_hipmer.sh for details):

1. (prepare input fastq files)
  1. They must be uncompressed
  2. They ought to be striped for efficient parallel access
  3. Paired reads must either be interleaved into 1 file, or separated into two files but FIXED
     length. Use interleave_fastq if you have variable length paired files 
2. prepare meraculous.config
3. ufx
4. contigs
5. contigMerDepth
6. if diploid:
    1. contigEndAnalyzer
    2. bubbleFinder
7. canonical_assembly (of contigs): canonical_contigs.fa
8. for each library:
    1. merAligner
    2. splinter (if specified in config file)
9. for each oNoSetID:
    1. for each library in that oNoSetId:
        1. merAlignerAnalyzer (histogrammer)
        2. spanner
    2. bmaToLinks
    3. oNo
10. gapclosing
11. canonical_assembly (of scaffolds): final_assembly.fa

This means that the first round of bmaToLinks could end up processing the 
outputs from multiple iterations of splinter plus multiple ones of spanner. The 
subsequent calls to bmaToLinks will only process outputs from spanner.