#!/bin/bash

# set UPC versions
CUPCVER=3.8.1-0
BUPCVER=2.24.2
CC=${CC:=gcc}
CXX=${CXX:=g++}
MPICC=${MPICC:=mpicc}
MPICXX=${MPICXX:=mpic++}

getcores()
{
  if lscpu
  then
     :
  fi 2>/dev/null | awk '/^CPU\(s\):/ {print $2}'
  if sysctl -a
  then
     :
  fi 2>/dev/null | awk '/^machdep.cpu.core_count/ {print $2}'
}
BUILD_THREADS=${BUILD_THREADS:=$(getcores)}

conduit=$1
#shift
if [ -n "$1" ]
then
  shm=$1
else
  shm=posix
fi

if [ -n "$2" ]
then
  installdir=${2}
else
  installdir=$HOME/install
fi

if [ -n "$3" ]
then
  builddir=${3}
else
  builddir=${TMPDIR:=/dev/shm}
fi
[ -d "$builddir" ] && [ -w "$builddir" ] || builddir=/tmp

if [ -n "$4" ]
then
  codedir=${4}
else
  codedir=$HOME
fi

[ -d $builddir ] || builddir=/tmp

USAGE="$0 Conduit(mpi|udp|smp) [ SHARED_MEMORY(posix|sysv|file|none) [ INSTALL_DIR($installdir) [ BUILD_DIR($builddir) [ CODE_DIR(${codedir}) ] ] ] ]"

if [ -z "$conduit" ] 
then
  echo $USAGE
  echo "You must choose a default networking conduit: mpi, udp or smp"
  echo
  exit 0
fi

oops()
{
  echo "uh oh, something bad happened!"
  exit 1
}

trap oops 0

set -e
set -x


cd $codedir
builddir=$builddir/$USER-hipmer-builds
mkdir -p ${builddir}

# install clang-upc and clang-upc2c

CUPCTAR=clang-upc-all-${CUPCVER}.tar.gz
CUPCURL=https://github.com/Intrepid/clang-upc/releases/download/clang-upc-${CUPCVER}/${CUPCTAR}
[ -f $CUPCTAR ] || curl -LO $CUPCURL
CUPCDIR=clang-upc-${CUPCVER}
[ -d $CUPCDIR ] || tar -xzf $CUPCTAR

mkdir -p $builddir/build_clangupc
cd $builddir/build_clangupc
cmake $codedir/$CUPCDIR -DCMAKE_INSTALL_PREFIX:PATH=$installdir -DLLVM_TARGETS_TO_BUILD:=host -DCMAKE_BUILD_TYPE:=Release
multiconf=
if make -j${BUILD_THREADS} && make install
then
  multiconf="+dbg_cupc2c,+opt_cupc2c"
else
  echo "Could not get clang-upc installed..."
fi
  


# install berkeley upc (with -cupc2c support)

cd $codedir

DIR=berkeley_upc-${BUPCVER}

TAR=$DIR.tar.gz
[ -f $TAR ] || curl -LO http://upc.lbl.gov/download/release/$TAR

[ -d $DIR ] || tar -xvzf berkeley_upc-${BUPCVER}.tar.gz
cd $DIR


edison_config="
 Configured with      | '--with-translator=/usr/common/ftg/upc/2.22.3/translato
                      | r/install/targ' '--enable-sptr-struct'
                      | '--disable-sptr-struct' '--with-sptr-packed-bits=10,18,
                      | 36' '--enable-cross-compile'
                      | '--host=x86_64-unknown-linux-gnu'
                      | '--build=x86_64-cnl-linux-gnu'
                      | '--target=x86_64-cnl-linux-gnu' '--program-prefix='
                      | '--disable-auto-conduit-detect' '--enable-mpi'
                      | '--enable-smp' '--disable-aligned-segments'
                      | '--enable-pshm' '--disable-pshm-posix'
                      | '--enable-pshm-xpmem' '--enable-throttle-poll'
                      | '--with-feature-list=os_cnl'
                      | '--enable-backtrace-execinfo' '--enable-aries'
                      | '--with-multiconf-file=multiconf_nersc.conf.in'
                      | '--with-multiconf=+opt,+dbg,+opt_trace,+opt_inst,
                      | +dbg_tv,+dbg_cupc2c,+opt_cupc2c,+opt_cupc2c_stats,
                      | +opt_cupc2c_trace,+opt_stats'
                      | '--prefix=/usr/common/ftg/upc/2.22.3/PrgEnv-intel-5.2.5
                      | 6-15.0.1.133-narrow/runtime/inst/opt'
                      | '--with-multiconf-magic=opt'
                      | 'build_alias=x86_64-cnl-linux-gnu'
                      | 'host_alias=x86_64-unknown-linux-gnu'
                      | 'target_alias=x86_64-cnl-linux-gnu' 'CC=cc -O0
                      | -wd10120'
----------------------+---------------------------------------------------------
 Configure features   | trans_bupc,pragma_upc_code,driver_upcc,runtime_upcr,
                      | gasnet,upc_collective,upc_io,upc_memcpy_async,
                      | upc_memcpy_vis,upc_ptradd,upc_thread_distance,upc_tick,
                      | upc_sem,upc_dump_shared,upc_trace_printf,
                      | upc_trace_mask,upc_local_to_shared,upc_all_free,pupc,
                      | upc_types,upc_castable,upc_nb,nodebug,notrace,nostats,
                      | nodebugmalloc,nogasp,nothrille,segment_fast,os_linux,
                      | cpu_x86_64,cpu_64,cc_intel,packedsptr,upc_io_64,os_cnl
"

mkdir -p $builddir/build-bupc
cd $builddir/build-bupc

SHM=
if [ "$shm" == "none" ]
then
  SHM="--disable-pshm --disable-aligned-segments"
elif [ "$shm" == "posix" ]
then
  SHM="--enable-pshm --enable-pshm-posix"
elif [ "$shm" == "sysv" ]
then
  SHM="--enable-pshm --disable-pshm-posix --enable-pshm-sysv"
elif [ "$shm" == "file" ]
then
  SHM="--enable-pshm --disable-pshm-posix --enable-pshm-file"
elif [ "$shm" == "xpmem" ]
then
  SHM="--enable-pshm --disable-pshm-posix --enable-pshm-xpmem"
fi

useconduit=""
if [ "$conduit" == 'ibv' ]
then
  useconduit="--enable-ibv"
elif [ "$conduit" == 'aries' ]
then
  useconduit="--enable-aries"
fi
if [ -n "${useconduit}" ]
then
  useconduit="--disable-auto-conduit-detect ${useconduit}"
fi

$codedir/$DIR/configure CC="${CC}" CXX="${CXX}" MPI_CC="${MPICC}" CUPC2C_TRANS=$installdir/bin/clang-upc2c --prefix=$installdir --with-multiconf=$multiconf $useconduit --enable-pthreads --enable-udp --enable-mpi --enable-smp --with-default-network=$conduit $SHM --enable-sptr-struct --disable-sptr-struct --with-sptr-packed-bits=10,18,36 && (make -j ${BUILD_THREADS} || make) && make install

set -x
trap "" 0

