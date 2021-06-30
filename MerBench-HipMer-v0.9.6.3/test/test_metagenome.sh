#!/bin/bash
#SBATCH --partition=debug
#SBATCH --nodes=4
#SBATCH --ntasks-per-node=24
#SBATCH --time=00:30:00
#SBATCH -L SCRATCH
#SBATCH --mail-type=ALL


if [ -z "$HIPMER_INSTALL" ]; then
    export HIPMER_INSTALL=$(dirname `dirname $0`)
fi

if [ -z "$HIPMER_TEST" ]; then
    # for checking output with standard 2.5% test case
    export HIPMER_POSTRUN="compare_diags.py ${HIPMER_INSTALL}/etc/meraculous/pipeline/metagenome.diags diags.log"
fi

N=$SLURM_JOB_NUM_NODES
export UPC_NODES=`scontrol show hostname`
export GASNET_MAX_SEGSIZE='903836KB'
export UPC_SHARED_HEAP_SIZE='500MB'
export MPICH_GNI_FMA_SHARING=enabled
#export AUTORESTART_UFX=1

USE_SBCAST=1 \
THREADS=$((60*N)) \
UPC_SHARED_HEAP_SIZE=500M \
HIPMER_DATA_DIR=$SCRATCH/hipmer_metagenome_data \
KMER_CACHE_MB=1 SW_CACHE_MB=2048 \
HIPMER_TEST=${HIPMER_TEST:=metagenome} ${HIPMER_INSTALL}/bin/test_hipmer.sh

