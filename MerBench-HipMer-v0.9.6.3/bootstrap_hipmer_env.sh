#!/bin/bash
#
# hipmer_common_env.sh [ command and arguments to execute ]
#
# Please do not modify this script for a specific machine environment
#
# All the environmental variables and functions to build, install and execute hipmer
# certain environmental variables can and should be overridden in a machine-specific
# environment file specified during build and automatically installed thereafter
#
# one should only need HIPMER_INSTALL or HIPMER_ENV_SCRIPT defined to boot strap
#

# first parse any ENV=val command line arguments

job_env_args=()
for arg in "$@"
do
  if [ "${arg/=}" != "${arg}" ]
  then
    job_env_args+=("export ${arg};")
    setenvlog="$setenvlog
Setenv $arg"
    eval "export ${arg%=*}='${arg##*=}'"
    shift
  else
    break
  fi
done

get_job_id()
{
  id="${PBS_JOBID}${SLURM_JOBID}${JOB_ID}"
  if [ -z "${id}" ]
  then
    id=$(uname -n).$$
  fi
  echo $id
}

# don't log for non-build, i.e. running test scripts
if [ -z "${SKIP_LOG}" ]
then 
    # automatically log
    HIPMER_BOOTSTRAP_FUNC=${HIPMER_BOOTSTRAP_FUNC:=bootstrap}
    if [ -n "$*" ] ; then HIPMER_BOOTSTRAP_FUNC=$(echo "$*" | tr ' ' '-') ; fi
    HIPMER_LOG=${HIPMER_LOG:=hipmer-${HIPMER_BOOTSTRAP_FUNC##*/}-$(get_job_id)-$(date '+%Y%m%d_%H%M%S').log}

    if [ -n "${HIPMER_AUTO_LOG}" ] || [ "${HIPMER_AUTO_LOG}" != "0" ]
    then
        echo "Logging everything to ${HIPMER_LOG}"
        exec 3>&1 1> >(tee -ia $HIPMER_LOG)
        exec 4>&2 2> >(tee -ia $HIPMER_LOG >&2)
        export HIPMER_AUTO_LOG=0
    fi
fi

echo "Set the following environment variables: ${setenvlog}"

#######################################################################################
#  compatibility functions                                                            #
#######################################################################################

OS=$(uname -s)
_readlink()
{
  local f=$1
  if [ "$OS" == "Darwin" ]
  then
    realpath $f
  else
    if [ -L $f ]
    then
      readlink $f
    else
      readlink -f $f
    fi
  fi
}

getsockets()
{
  if [ "$OS" == "Darwin" ]
  then
    echo 1
  elif [ -x $(which lscpu || true) ]
  then
     lscpu --parse | awk -F, '!/^#/ {print $3}' | sort | uniq | wc -l
  elif [ -f /proc/cpuinfo ]
  then
    grep '^physical id' /proc/cpuinfo | sort | uniq | wc -l
  else
    echo 1
  fi
}

# auto-detect the number of cores per node
getcores()
{
  if [ "$OS" == "Darwin" ]
  then
     sysctl -a 2>/dev/null | awk '/^machdep.cpu.core_count/ {print $2}'
  elif  [ -x $(which lscpu || true) ]
  then
     lscpu --parse | awk -F, '!/^#/ {print $2}' | sort | uniq | wc -l
  elif [ -f /proc/cpuinfo ]
  then
     echo $(( $(grep "^physical id" /proc/cpuinfo | sort | uniq | wc -l) * $(awk '/cpu cores/ {print $4; exit;}' /proc/cpuinfo) ))
  else
     echo 1
  fi
}

# auto-detect the number of cpus (cores * hyperthreads) per node
getthreads()
{
  if [ "$OS" == "Darwin" ]
  then
     sysctl -a 2>/dev/null | awk '/^machdep.cpu.thread_count/ {print $2}'
  elif [ -x $(which lscpu || true) ]
  then
     lscpu --parse | awk -F, '!/^#/ {print $1}' | sort | uniq | wc -l
  elif [ -f /proc/cpuinfo ]
  then
     cat /proc/cpuinfo | grep "^processor" | wc -l
  else
     echo 1
  fi
}

getcorespersocket()
{
  echo $(( $(getcores) / $(getsockets) ))
}

getnodelist()
{
  cpn=$1
  nodelist=$2
  nodes="$(echo ${nodelist} | tr ',' ' ')"
  numnodes=$(echo ${nodes} | wc -w)
  echo "Translating UPC_NODES from ${cpn} x ${nodelist} "
  nodelist=$(
  for node in ${nodes}
  do
    for core in $(seq 1 ${cpn})
    do
      printf "${node},"
      numcores=$((numcores+1))
    done
  done
  )
  export CORES_PER_NODE=${cpn}
  export THREADS=$((numnodes*cpn))
  export UPC_NODES=${nodelist%,}
  echo UPC_NODES=${UPC_NODES}
  echo THREADS=${THREADS}
}
 
if [ -z "${INSTALL_PREFIX}" ] || [ ! -d "${INSTALL_PREFIX}" ]
then
  cd $SCRATCH # if it exists great! otherwise going to HOME
  INSTALL_PREFIX=$(pwd -P)
  cd -
  echo "Set INSTALL_PREFIX=${INSTALL_PREFIX}"
fi

echo "Currently in $(pwd)"

if [ -z "${HIPMER_ENV_SCRIPT}" ] || [ ! -f "${HIPMER_ENV_SCRIPT}" ]
then

  testenv=${0%${0##*/}}hipmer_env.sh
  echo "First checking for ${testenv}"
  if [ -f "${testenv}" ]
  then
    echo "Detected default HIPMER_ENV_SCRIPT at ${testenv}... Using this"
    export HIPMER_ENV_SCRIPT=${testenv}
  else
    # attempt to bootstrap if called via fully qualified path within a valid HIPMER_INSTALL/bin directory
    ABSOLUTE_PATH=$0
    if [ -n "${ABSOLUTE_PATH##/*}" ]
    then
       # attempt to get resolve relative path
       ABSOLUTE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
    fi

    testbin=${ABSOLUTE_PATH%/*}
    if [ -x "${testbin}/run_hipmer.sh" ]
    then
       export HIPMER_INSTALL=${testbin%/*}
       echo "Next checking for ${HIPMER_INSTALL}/env.sh"
       if [ -f ${HIPMER_INSTALL}/env.sh ]
       then
         export HIPMER_ENV_SCRIPT=${HIPMER_INSTALL}/env.sh
       fi
    fi
  fi

  if [ -z "${HIPMER_ENV_SCRIPT}" ] || [ ! -f "${HIPMER_ENV_SCRIPT}" ]
  then
    # HIPMER_INSTALL - global directory where the code is (or will be) installed
    export HIPMER_INSTALL=${HIPMER_INSTALL:=$INSTALL_PREFIX/hipmer-install}
    if [ -d "${HIPMER_INSTALL}"-$(uname -s) ]
    then
      export HIPMER_INSTALL=${HIPMER_INSTALL}-$(uname -s)
    fi

    # machine / install specific environment that overrides defaults in this file
    HIPMER_ENV_SCRIPT=${HIPMER_ENV_SCRIPT:=${HIPMER_INSTALL}/env.sh}
    if [ -f "${HIPMER_ENV_SCRIPT}" ]
    then
      export HIPMER_ENV_SCRIPT
    else
      unset HIPMER_ENV_SCRIPT
      unset HIPMER_INSTALL
    fi
  fi
fi

if [ -f "${HIPMER_ENV_SCRIPT}" ]
then
  echo "Sourcing ${HIPMER_ENV_SCRIPT}"
  source ${HIPMER_ENV_SCRIPT}
else
  echo "No HIPMER_ENV_SCRIPT was found"
fi

# SCRATCH must be global shared, (i.e. where you want to save code and results)
export SCRATCH=${SCRATCH:=$INSTALL_PREFIX/hipmer-scratch}
[ -d $SCRATCH ] || mkdir ${SCRATCH}

HIPMER_ENV=${HIPMER_ENV:=$(uname -s)}
export HIPMER_INSTALL=${HIPMER_INSTALL:=$INSTALL_PREFIX/hipmer-install-${HIPMER_ENV}}
[ ! -d "${HIPMER_INSTALL}/bin" ] || export PATH=${HIPMER_INSTALL}/bin:$PATH

# TMPDIR is high speed and okay to be local
export TMPDIR=${TMPDIR:=/tmp}

# HIPMER_BUILD - only used for building the code
export HIPMER_BUILD=${HIPMER_BUILD:=${TMPDIR}/${USER}-hipmer-build-${HIPMER_ENV}}

export CC=${CC:=$(which cc || which icc || which gcc)}
export CXX=${CXX:=$(which CC || which c++ || which icpc || which g++)}
export MPICC=${MPICC:=$(which mpicc)}
export MPICXX=${MPICXX:=$(which mpic++)}
export UPCC=${UPCC:=${HIPMER_UPCC:=$(which upcc)}}
export MPIRUN=${MPIRUN:=$(which mpirun 2>/dev/null || which srun 2>/dev/null || true)} # MPIRUN is only necessary in stages!
export UPCRUN=${UPCRUN:=$(which upcrun) -q}
export CMAKE_BIN=${CMAKE_BIN:=$(which cmake)}
export LFS=${LFS:=$(which lfs 2>/dev/null || true)}

MYENV="
  CC=${CC}			- the C compiler (potentially mpi-enabled)
  CXX=${CXX}			- the C++ compiler (potentially mpi-enabled)
  MPICC=${MPICC}		- the MPI C compiler / linker
  MPICXX=${MPICXX}		- the MPI C++ compiler / linker
  UPCC=${UPCC}			- the UPC compiler
  MPIRUN=${MPIRUN}		- the mpirun command
  UPCRUN=${UPCRUN}		- the upcrun command
  CMAKE_BIN=${CMAKE_BIN}	- the cmake command
  LFS=${LFS}			- the (optional) path to Luster File System control script
  HIPMER_UDP_NODES=${HIPMER_UDP_NODES} 
                                - if compiled with UDP conduit, set this to the list of nodes (once per node) to automatically generate the UPC_NODES and THREADS env var
"

MYDIRS="
  TMPDIR=${TMPDIR} - fast, local directory (i.e. /tmp or /dev/shm)
  SCRATCH=${SCRATCH} - global, shared, networked directory (${INSTALL_PREFIX}/hipmer-scratch)
  INSTALL_PREFIX=${INSTAL_PREFIX} ($HOME)
  HIPMER_INSTALL=${HIPMER_INSTALL} - global installation directory (${INSTALL_PREFIX}/hipmer-install)
"

test_building()
{
  foundall=1
  for test_exe in "$CC" "$CXX" "$MPICC" "$MPICXX" "$UPCC" "${CMAKE_BIN}"
  do
    if [ ! -x "$(which ${test_exe})" ]
    then
      foundall=0
      echo "Failed to find ${test_exe}!" 1>&2
    fi
  done
  

  if [ ${foundall} -ne 1 ]
  then
    echo "You must have specified the following environmental variables:
${MYENV}

Perhaps you should set and/or configure a machine specific HIPMER_ENV_SCRIPT?
" 1>&2
    exit 1
  fi
}

for testdir in "${TMPDIR}" "${SCRATCH}" "${HIPMER_INSTALL%/*}"
do
  if [ ! -d "${testdir}" ]
  then
    echo "You must specify valid paths for the following variables:
${MYDIRS}

${testdir} could not be found
Perhaps you should set and/or configure a machine specific HIPMER_ENV_SCRIPT?
" 1>&2
    exit 1
  fi
done

for testdir in "${TMPDIR}" "${SCRATCH}"
do 
  if [ ! -w "${testdir}" ]
  then
     echo "You must be able to write to $testdir!" 1>&2
     exit 1
  fi
done

#######################################################################################
#  These variables should be overridden where necessary for each platform.            #
#  Ideally within the hipmer_env.sh script ($HIPMER_ENV_SCRIPT) referenced above.     #
#######################################################################################

# define the build type and options (Release, Debug, RelWithDebugFlags)
export HIPMER_BUILD_TYPE=${HIPMER_BUILD_TYPE:=Release}
export HIPMER_BUILD_OPTS="${HIPMER_BUILD_OPTS:=}"
export HIPMER_SRC=${HIPMER_SRC:=$(pwd)}
export HIPMER_POST_INSTALL=${HIPMER_POST_INSTALL:=}

export PHYS_MEM_MB=${PHYS_MEM_MB:=$(awk '/MemTotal:/ { t=$2 ; print int(t / 1024)}' /proc/meminfo 2>/dev/null || sysctl -a | awk '/hw.memsize:/ {t=$2; print int(t/1024/1024)}' || echo 8000)}
MIN_RESERVED_MEM=$((PHYS_MEM_MB/20)) # 5% reserved
[ ${MIN_RESERVED_MEM} -gt 2000 ] || MIN_RESERVED_MEM=2000 # at least 2GB reserved
PHYS_MEM_MB=$((PHYS_MEM_MB-MIN_RESERVED_MEM))
if [ -z "${HIPMER_PROBE_MEM}" ]
then
  export GASNET_PHYSMEM_MAX=${GASNET_PHYSMEM_MAX:=${PHYS_MEM_MB}MB}
  export GASNET_PHYSMEM_NOPROBE=${GASNET_PHYSMEM_NOPROBE:=1}
fi

export CORES_PER_NODE=${CORES_PER_NODE:=$(getcores)}
export BUILD_THREADS=${BUILD_THREADS:=${CORES_PER_NODE}}

export HIPMER_SHARED_MEM_PCT=${HIPMER_SHARED_MEM_PCT:=48}
export HIPMER_UPC_ALLOCATOR=${HIPMER_UPC_ALLOCATOR:=1}

UPC_PTHREADS=${UPC_PTHREADS:=}
UPC_PTHREADS_OPT=
if [ -n "$UPC_PTHREADS" ] && [ $UPC_PTHREADS -ne 0 ]
then
  UPC_PTHREADS_OPT="-pthreads=${UPC_PTHREADS}"
fi

if [ -z "$HIPMER_EMBED_HMMER" ]
then
  export HIPMER_EMBED_HMMER=1
fi

##################################################################################
#          YOU SHOULD NEVER NEED TO MODIFY ANYTHING BELOW HERE                   #
##################################################################################

export DIST_CLEAN=${DIST_CLEAN:=}
export CLEAN=${CLEAN:=}

export HYPERTHREADS=${HYPERTHREADS:=$(( ${CORES_PER_NODE} / $(getcores) ))}
[ -z "${HIPMER_UDP_NODES}" ] || getnodelist ${CORES_PER_NODE} ${HIPMER_UDP_NODES}

set_dir_striping()
{
  local stripe=$1
  local dir=$2
  echo "set_dir_striping ${stripe} ${dir}"
  if [ -x "${LFS}" ]
  then
     lfsdf=$(${LFS} df ${dir})
     if [ -z "${lfsdf}" ]
     then
         echo "LUSTRE is not on ${dir}"
     else
       if [ "$stripe" == "-1" ]
       then
          stripe=$(( $(echo "${lfsdf}" | grep -c _UUID) * 8 / 10))
          echo "using stripe ${stripe} instead of -1"
       fi

       if [ ${stripe} -le 1 ]
       then
           stripe=1
       fi
       echo "Setting lustre stripe to ${stripe} on ${dir}"
       ${LFS} setstripe -c ${stripe} ${dir} || true
     fi
  else
     echo "LFS not detected, skipping stripe count $1 on $2"
  fi
}

build_hipmer_call_cmake()
{
  cd ${HIPMER_BUILD}
  cmakelog=${HIPMER_BUILD}/cmake.log
  if [ ! -f ${cmakelog} ]
  then
    # support other environmental variable based build options
    HIPMER_BUILD_OPTS2=
    [ -z "${HIPMER_FULL_BUILD}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_FULL_BUILD=${HIPMER_FULL_BUILD}"
    [ -z "${HIPMER_STATIC_BUILD}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_STATIC_BUILD=${HIPMER_STATIC_BUILD}"
    [ -z "${HIPMER_KHASH}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_KHASH=${HIPMER_KHASH}"
    [ -z "${HIPMER_USE_PTHREADS}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DCMAKE_UPC_USE_PTHREADS=${HIPMER_USE_PTHREADS}"
    [ -z "${HIPMER_READ_BUFFER}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_READ_BUFFER=${HIPMER_READ_BUFFER}"
    [ -z "${HIPMER_MAX_KMER_SIZE}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_MAX_KMER_SIZE=${HIPMER_MAX_KMER_SIZE}"
    [ -z "${HIPMER_KMER_LENGTHS}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_MAX_KMER_SIZE=${HIPMER_KMER_LENGTHS}"
    [ -z "${HIPMER_MAX_FILE_PATH}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_MAX_KMER_SIZE=${HIPMER_MAX_FILE_PATH}"
    [ -z "${HIPMER_MAX_READ_NAME}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_MAX_READ_NAME=${HIPMER_MAX_READ_NAME}"
    [ -z "${HIPMER_MAX_LIBRARIES}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_MAX_LIBRARIES=${HIPMER_MAX_LIBRARIES}"
    [ -z "${HIPMER_LIB_NAME_LEN}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_LIB_NAME_LEN=${HIPMER_LIB_NAME_LEN}"
    [ -z "${HIPMER_VERBOSE}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_VERBOSE=${HIPMER_VERBOSE}"
    [ -z "${HIPMER_BLOOM}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_BLOOM=${HIPMER_BLOOM}"
    [ -z "${HIPMER_DISCOVER_LIBC}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_DISCOVER_LIBC=${HIPMER_DISCOVER_LIBC}"
    [ -z "${HIPMER_SLACK}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_SLACK=${HIPMER_SLACK}"
    [ -z "${HIPMER_CHUNK_SIZE}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_CHUNK_SIZE=${HIPMER_CHUNK_SIZE}"
    [ -z "${HIPMER_UPC_ALLOCATOR}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DUPC_ALLOCATOR=${HIPMER_UPC_ALLOCATOR}"
    [ -z "${HIPMER_NO_UPC_MEMORY_POOL}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DNO_UPC_MEMORY_POOL=1"
    [ -z "${HIPMER_BROKEN_ALLOCATOR_REBIND}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DBROKEN_ALLOCATOR_REBIND=1"
    [ -z "${HIPMER_NO_UNIT_TESTS}" ] ||  HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_NO_UNIT_TESTS=${HIPMER_NO_UNIT_TESTS}"
    [ -z "${HIPMER_NO_GZIP}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_NO_GZIP=${HIPMER_NO_GZIP}"
    [ -z "${HIPMER_TEST}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_TEST=1"
    [ -z "${HIPMER_HWATOMIC}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_HWATOMIC=${HIPMER_HWATOMIC}"
    [ -z "${HIPMER_NO_AVX512F}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_NO_AVX512F=${HIPMER_NO_AVX512F}"
    [ -z "${HIPMER_NO_AIO}" ] ||  HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_NO_AIO=${HIPMER_NO_AIO}"
    [ -z "${HIPMER_EMBED_HMMER}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_EMBED_HMMER=${HIPMER_EMBED_HMMER}"
    [ -z "${HIPMER_HMMER_CONFIGURE_OPTS}" ] || HIPMER_BUILD_OPTS2="${HIPMER_BUILD_OPTS2} -DHIPMER_HMMER_CONFIGURE_OPTS='${HIPMER_HMMER_CONFIGURE_OPTS}'"
    HIPMER_UPC_COMPILER=
    [ -z "${HIPMER_UPCC}" ] || HIPMER_UPC_COMPILER="-DCMAKE_UPC_COMPILER='${HIPMER_UPCC}'"
    HIPMER_UPC_FLAGS_INIT=
    [ -z "${HIPMER_UPC_FLAGS}" ] || HIPMER_UPC_FLAGS_INIT="-DCMAKE_UPC_FLAGS_INIT='${HIPMER_UPC_FLAGS}'"
    CMAKE_CXX11_FLAG=
    [ -z "${HIPMER_CXX11_FLAG}" ] || CMAKE_CXX11_FLAG="-DCXX11_FLAG='${HIPMER_CXX11_FLAG}'"
    set -e
    set -x
    eval cmake -DCMAKE_INSTALL_PREFIX=${HIPMER_INSTALL} -DCMAKE_BUILD_TYPE=${HIPMER_BUILD_TYPE} \
        ${HIPMER_BUILD_OPTS} \
        ${HIPMER_BUILD_OPTS2} \
        ${HIPMER_UPC_COMPILER} ${HIPMER_UPC_FLAGS_INIT} ${CMAKE_CXX11_FLAG} \
        -DMPI_C_COMPILER="${MPICC}" -DMPI_CXX_COMPILER="${MPICXX}" \
        ${HIPMER_SRC} 2>&1 | tee -a ${cmakelog}.tmp && [ ${PIPESTATUS[0]} -eq 0 ] \
    && mv ${cmakelog}.tmp ${cmakelog} || ret=1
    set +x
    set +e
  fi
  cd -
  return $ret
}

clean_or_make_hipmer_build_dir()
{
  if [ -e "${HIPMER_BUILD}" ]
  then
    # check for same source directory
    cmakecache=${HIPMER_BUILD}/CMakeCache.txt
    if [ -f ${cmakecache} ]
    then
      testsrc=$(grep HipMer_SOURCE_DIR ${cmakecache} | sed 's/.*=//;')
      if [ "${testsrc}" != "${HIPMER_SRC}" ]
      then
        echo "Source dirs do not match ${testsrc} vs ${HIPMER_SRC}. performing a DIST_CLEAN build to ${HIPMER_SRC}"
        export DIST_CLEAN=1
      fi
    fi
  fi

  if [ -n "${DIST_CLEAN}" ] && [ -d "${HIPMER_BUILD}" ]
  then
    echo "Cleaning out old builds HipMer: ${HIPMER_BUILD}"
    chmod -R u+w ${HIPMER_BUILD}
    rm -r ${HIPMER_BUILD}
  fi
  unset DIST_CLEAN
  if [ ! -d ${HIPMER_BUILD} ]
  then
    echo "Creating build dir: ${HIPMER_BUILD}"
    mkdir ${HIPMER_BUILD}
    set_dir_striping 1 ${HIPMER_BUILD}
    if (cd ${HIPMER_BUILD} && build_hipmer_call_cmake)
    then
       echo "CMake environment is ready"
    else
       echo "Could not prepare the build environment."
       exit 1
    fi
  fi
  echo "Using build dir: ${HIPMER_BUILD}"
  if [ -n "${CLEAN}" ] && [ "${CLEAN}" == "1" ]
  then
    (cd ${HIPMER_BUILD} ; make clean )
  fi
}

build()
{
  set -e
  test_building
  clean_or_make_hipmer_build_dir
  ret=0
  build_hipmer_call_cmake || ret=$?
  if [ ${ret} -eq 0 ]
  then
    cd ${HIPMER_BUILD}
    time make REPLACE_VERSION_H || ret=$?
  else
    if [ "${DIST_CLEAN}" != "1" ] && [ "${LAST_TRY}" != "1" ]
    then
      # try again
      export DIST_CLEAN=1
      export LAST_TRY=1
      build
      unset DIST_CLEAN
      return
    else
      echo
      echo "Could not make REPLACE_VERSION_H... Please retry setting DIST_CLEAN=1 before contacting the developers"
      echo
      exit 1
    fi
  fi
  if [ "${VERBOSE}" == "1" ]
  then
    export BUILD_THREADS=1
  fi
  time make -j ${BUILD_THREADS} 2>&1 | tee build.log | grep -v "jobserver unavailable" && [ ${PIPESTATUS[0]} -eq 0 ] || return 1
  cd -
  echo "Building complete"
  set +e
}

install()
{
  set -e
  clean_or_make_hipmer_build_dir
  [ -d ${HIPMER_BUILD} ] && [ "${DIST_CLEAN}" != "1" ] || build
  if [ -z "${HIPMER_INSTALL}" ] ; then echo "Can not install -- empty HIPMER_INSTALL variable"; return ; fi
  cd ${HIPMER_BUILD}
  if [ "${DIST_CLEAN}" == "1" ] && [ -d "${HIPMER_INSTALL}" ]
  then
    [ -w "${HIPMER_INSTALL}/." ] && rm -r ${HIPMER_INSTALL}/. || echo "Could not DIST_CLEAN HIPMER_INSTALL: ${HIPMER_INSTALL}" 1>&2
  fi

  mkdir -p ${HIPMER_INSTALL}
  set_dir_striping 1 ${HIPMER_INSTALL}
  if [ "${VERBOSE}" == "1" ]
  then
    export BUILD_THREADS=1
  fi
  time make REPLACE_VERSION_H && \
  time make -j ${BUILD_THREADS} 2>&1|grep -v "jobserver unavailable" && [ ${PIPESTATUS[0]} -eq 0 ] && \
  make install test 2>&1 | tee install.log | grep -v "jobserver unavailable" && [ ${PIPESTATUS[0]} -eq 0 ] || return 1
  
  cd -

  # copy conf and bin scripts if they exist
  if [ -n "${HIPMER_BIN_SCRIPTS}" ]
  then
    ( cd ${HIPMER_ENV_SCRIPT%/*} && cp -p ${HIPMER_BIN_SCRIPTS} ${HIPMER_INSTALL}/bin ) || echo "WARNING: Could not copy HIPMER_BIN_SCRIPTS=${HIPMER_BIN_SCRIPTS}"
  fi
  if [ -n "${HIPMER_UPCRUN_CONF}" ]
  then
    ( cd ${HIPMER_ENV_SCRIPT%/*} && cp -p ${HIPMER_UPCRUN_CONF} ${HIPMER_INSTALL} ) || echo "WARNING: Could not copy HIPMER_UPCRUN_CONF=${HIPMER_UPCRUN_CONF}"
  fi

  # prepare the installed environment script
  newenv=${HIPMER_INSTALL}/env.sh
  if [ "${newenv}" != "${HIPMER_ENV_SCRIPT}" ] || [ ! -f ${newenv} ]
  then
    (
     [ ! -f "${HIPMER_ENV_SCRIPT}" ] || cat ${HIPMER_ENV_SCRIPT};
     cat <<HERE_EOF

# These are the machine specific environmental variables for this install

export HIPMER_INSTALL=${HIPMER_INSTALL}
export HIPMER_ENV_SCRIPT=${newenv}
export HIPMER_ENV=${HIPMER_ENV}

# runtime parameters
export HYPERTHREADS=\${HYPERTHREADS:=${HYPERTHREADS}}
export SCRATCH=\${SCRATCH:=$SCRATCH}

# machine specific method to execute mpi & upc; default memory per thread for UPC
export MPIRUN=\${MPIRUN:=${MPIRUN}}
export UPCRUN=\${UPCRUN:=${UPCRUN}}

if [ -n "\${HIPMER_PROBE_MEM}" ]
then
  unset PHYS_MEM_MB
  unset GASNET_PHYSMEM_MAX
  unset UPC_SHARED_HEAP_SIZE
  unset GASNET_PHYSMEM_NOPROBE
else
  #export PHYS_MEM_MB=\${PHYS_MEM_MB:=${PHYS_MEM_MB}}
  #export GASNET_PHYSMEM_MAX=\${GASNET_PHYSMEM_MAX:=${GASNET_PHYSMEM_MAX}}
  #export UPC_SHARED_HEAP_SIZE=\${UPC_SHARED_HEAP_SIZE:=${UPC_SHARED_HEAP_SIZE}}
  export GASNET_PHYSMEM_NOPROBE=\${GASNET_PHYSMEM_NOPROBE:=${GASNET_PHYSMEM_NOPROBE}}
fi

export UPC_PTHREADS_OPT=\${UPC_PTHREADS_OPT:=${UPC_PTHREADS_OPT}}

# Compilers
export CC=${CC}
export CXX=${CXX}
export MPICC=${MPICC}
export MPICXX=${MPICXX}
export UPCC=${UPCC}
export CMAKE_BIN=${CMAKE_BIN}

# build parameters
export HIPMER_BUILD_TYPE=${HIPMER_BUILD_TYPE}
export HIPMER_BUILD_OPTS="${HIPMER_BUILD_OPTS}"
export HIPMER_SRC=${HIPMER_SRC}
export HIPMER_POST_INSTALL=${HIPMER_POST_INSTALL}
export HIPMER_POSIX_SHM=\${HIPMER_POSIX_SHM:=${HIPMER_POSIX_SHM}}
export HIPMER_SHARED_MEM_PCT=\${HIPMER_SHARED_MEM_PCT:=${HIPMER_SHARED_MEM_PCT}}
export HIPMER_UPC_ALLOCATOR=\${HIPMER_UPC_ALLOCATOR:=${HIPMER_UPC_ALLOCATOR}}

HERE_EOF
    ) > ${newenv}

    export HIPMER_ENV_SCRIPT=${newenv}
  fi

  if [ -n "${HIPMER_POST_INSTALL}" ]
  then
    ${HIPMER_POST_INSTALL} || true
  fi

  echo "HipMer installation complete"
  set +e
}

test()
{
  set -e
  clean_or_make_hipmer_build_dir
  [ -d ${HIPMER_BUILD} ] && [ "${DIST_CLEAN}" != "1" ] || build
  cd ${HIPMER_BUILD}
  make test
}

get_job_tasks()
{
  if [ -n "${SLURM_NTASKS}" ]
  then
    echo ${SLURM_NTASKS}
  elif [ -n "${NSLOTS}" ]
  then
    echo ${NSLOTS}
  elif [ -n "$PBS_NODEFILE" ]
  then
    echo $(($(cat ${PBS_NODEFILE} | wc -l) * ${CORES_PER_NODE}))
  else
    echo ${CORES_PER_NODE}
  fi
}
__THR=${THREADS}
export THREADS=${THREADS:=$(get_job_tasks)}

UPC_POLITE_SYNC=${UPC_POLITE_SYNC:=}
if [ ${THREADS} -lt ${CORES_PER_NODE} ]
then
  # support 1 thread or less than the cores in one node on a single node
  echo "Overriding CORES_PER_NODE from ${CORES_PER_NODE} to ${THREADS}"
  export CORES_PER_NODE=${THREADS}
elif [ $((THREADS % CORES_PER_NODE)) -ne 0 ]
then
  echo "Overriding THREADS from ${THREADS} to be a mulitple of ${CORES_PER_NODE}"
  export THREADS=$((THREADS - (THREADS % CORES_PER_NODE)))
fi

export CACHED_IO=${CACHED_IO:=$((THREADS!=CORES_PER_NODE))} # use CACHED_IO if multi-node
# set the shared heap size if not already set
if [ -z ${UPC_SHARED_HEAP_SIZE} ]; then
    PERC=${HIPMER_SHARED_MEM_PCT}
    [ "$CACHED_IO" ] && PERC=$((HIPMER_SHARED_MEM_PCT/2))
    export UPC_SHARED_HEAP_SIZE=$((PERC*PHYS_MEM_MB/CORES_PER_NODE/100))
    echo "+ UPC_SHARED_HEAP_SIZE not set, using ${PERC}% of maximum memory: ${UPC_SHARED_HEAP_SIZE} MB per thread"
fi

if [ ${HYPERTHREADS} -gt 1 ]
then
  export UPC_POLITE_SYNC=1
fi

setup_RUNDIR()
{
  myname=$1
  [ -n "${myname}" ] || myname=HipMer
  export RUNDIR=${RUNDIR:=$SCRATCH/${myname}-${THREADS}-$(get_job_id)-$(date '+%Y%m%d_%H%M%S')}
  mkdir -p ${RUNDIR}/per_thread
  mkdir -p ${RUNDIR}/results ${RUNDIR}/intermediates
  set_dir_striping -1 ${RUNDIR}/results
  set_dir_striping -1 ${RUNDIR}/intermediates
  set_dir_striping 1 ${RUNDIR}/per_thread
  set_dir_striping 1 ${RUNDIR}/.
  echo "created RUNDIR=${RUNDIR}"
}

echo "The following environment is now active:

THREADS=${THREADS}

$(env | grep '\(HIPMER\|GASNET\|UPC\|CORES_PER_NODE\|HYPERTHREADS\)')

PATH=${PATH}
"

if [ -f "$HIPMER_INSTALL/HIPMER_VERSION" ]
then
  HIPMER_BOOTSTRAPPED=$(cat $HIPMER_INSTALL/HIPMER_VERSION)
  export HIPMER_VERSION=${HIPMER_BOOTSTRAPPED}
  echo "HIPMER_VERSION: ${HIPMER_VERSION}"
else
  HIPMER_BOOTSTRAPPED=1
fi

EXIT_VAL=0
endlog()
{
  if [ -n "${HIPMER_LOG}" ]
  then
    exec 1>&3 2>&4
    echo "You should be able to find a log of everything that just happened at ${HIPMER_LOG}"
  fi
  trap '' 0
  if [ -n "$@" ] || [ ${EXIT_VAL} -ne 0 ]
  then
    exit $@ ${EXIT_VAL}
  fi
}

if [ -n "$*" ] && [ "${0##*/}" == "bootstrap_hipmer_env.sh" ]
then
  echo "$0 (bootstrap) will now execute: $@"
  $@
  EXIT_VAL=$?
  echo "$0 (bootstrap) finished executing with exit val: ${EXIT_VAL}"
  trap "" 0
  endlog
  exit ${EXIT_VAL}
fi

