# Configuring your Mac OS X to compile and execute MPI and UPC code

### Download and install [XCode](https://developer.apple.com/xcode/) from the Apple Store 

    (This is free but you must accept Terms and Conditions)

### Download and install [HomeBrew](http://brew.sh). This is also free and well respected open source software packager.

(open your terminal)

    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`

### Install required packages from HomeBrew

(open your terminal)


    brew update
    brew upgrade
    brew install open-mpi cmake coreutils
    brew install argp-standalone

### Download and unpack HipMer (if not already done)

 [Get the latest from sourceforge.org](https://sourceforge.net/projects/hipmer/files/)
 cd $HOME/Downloads
 tar -xzf HipMer*.tar.gz
 cd HipMer*


### Download and install [Berkeley UPC](http://upc.lbl.gov) and Clang-upc2c (and Clang-upc)

  CC=cc CXX=c++ contrib/install_upc.sh mpi sysv

### Configure system V shared memory limits
By default Apple only allows 30MB of shared memory to your applications.  
HipMer requires these limits to be expanded to the amount of memory you intend
to use for the assembly.  Here is an example of configuring shared memory to a maximum
of 4GB (okay for very small assemblies)

    echo "First copy any existing configs"
    
    cat /etc/sysctl.conf > /tmp/sysctl.conf 2>/dev/null || true
    
    echo "Raise the shmmax and shmall limits to 4GB and 256MB respectively"
    
    echo "kern.sysv.shmmax=4294967296
    kern.sysv.shmmin=128
    kern.sysv.shmmni=32
    kern.sysv.shmseg=32
    kern.sysv.shmall=4194304
    " >> /tmp/sysctl.conf
     
    echo "Or rasise the limit to 8GB"
    
    echo"kern.sysv.shmmax=8589934592
    kern.sysv.shmmin=128
    kern.sysv.shmmni=32
    kern.sysv.shmseg=32
    kern.sysv.shmall=8388608
    " >> /tmp/sysctl.conf
    
    echo "Copy them to the system and apply them"
    
    sudo cp /tmp/sysctl.conf /etc/sysctl.conf
    sudo /usr/sbin/sysctl -w $(cat /etc/sysctl.conf)
    
    Now, reboot to let the changes take effect

### Compile and install HipMer
 [Get the latest from sourceforge.org](https://sourceforge.net/projects/hipmer/files/)

(in your terminal)

    cd $HOME/Downloads
    cd HipMer*
    ln -s .macosx_deploy/env.sh hipmer_env.sh
    ./bootstrap_hipmer_env.sh install


