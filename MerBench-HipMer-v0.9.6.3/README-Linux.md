# Configuring your Ubuntu 14.04 to compile and execute MPI and UPC code

### Install required packages 

(open your terminal)

    sudo apt-get install build-essential cmake git 
    sudo apt-get install openmpi-common libopenmpi-dev openmpi-doc openmpi-bin

### Download and install [Berkeley UPC](http://upc.lbl.gov)

Download: [berkeley_upc-2.22.0](http://upc.lbl.gov/download/release/berkeley_upc-2.22.0.tar.gz)

    wget http://upc.lbl.gov/download/release/berkeley_upc-2.22.0.tar.gz
    tar -xvzf berkeley_upc-2.22.0.tar.gz 
    cd berkeley_upc-2.22.0
    mkdir build
    cd build
    ../configure CC=cc CXX=c++ MPI_CC=mpicc --prefix=/usr/local \
        --disable-ibv --enable-pthreads --enable-udp --enable-mpi \
        --enable-smp --with-default-network=smp --enable-pshm 
    make
    sudo make install


### Download and install HipMer
 [Get the latest from sourceforge.org](https://sourceforge.net/projects/hipmer/files/)

(in your terminal)


    cd $HOME/Downloads
    tar -xzf HipMer*.tar.gz
    cd HipMer*
    export SCRATCH=/tmp
    .generic_deploy/build.sh && .generic_deploy/install.sh


