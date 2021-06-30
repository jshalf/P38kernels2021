#!/bin/bash

myip=$(curl http://instance-data/latest/meta-data/local-ipv4)
publicip=$(curl http://instance-data/latest/meta-data/public-ipv4)
echo "Hello from $myip $publicip"
EFS=fs-98a173d1

mountefs()
{
  local efs=$1
  local efsmount=$(curl -s http://instance-data/latest/meta-data/placement/availability-zone).$efs.efs.us-east-1.amazonaws.com
  mkdir -p /efs
  
  if mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $efsmount:/ /efs
  then
    (cd /nscratch/. && for i in /efs/* ; do [ -d ${i} ] && [ -d ${i##*/} ] || ln -s $i || /bin/true ; done )
  fi
}

USE_GLUSTER=${USE_GLUSTER:=0}

check_root()
{
  if [ "${USER}" != "root" ]
  then
    echo "$0 $@ must be executed as root.  please sudo $0 $@"
    exit 1
  fi
}

user=
for u in ubuntu ec2-user
do
  [ -d /home/$u ] && user=$u
done

HOSTS=${HOSTS:=/home/${user}/ourhosts}
if [ -z "$*" ] && [ ! -f "${HOSTS}" ]
then
  echo "Please list all the hosts in the cluster in ${HOSTS}"
  exit 1
fi

IS_APT=
if apt-get --version 2>/dev/null
then
  IS_APT=1
else
  export USE_GLUSTER=0 # no gluster in redhat yet
fi

copy_sshkeys()
{
  check_root
  if ! diff -q ~root/.ssh/id_rsa.pub /home/${user}/.ssh/id_rsa.pub
  then
    cp /home/${user}/.ssh/id_rsa* ~root/.ssh
    cat ~root/.ssh/id_rsa.pub >> ~root/.ssh/authorized_keys
    chmod 600 ~root/.ssh/authorized_keys ~root/.ssh/id_rsa ~root/.ssh/config
  fi
  grep -q StrictHostKeyChecking ~root/.ssh/config || echo "StrictHostKeyChecking no" >> ~root/.ssh/config
  grep -q NoHostAuthenticationForLocalhost ~root/.ssh/config || echo "NoHostAuthenticationForLocalhost yes" >> ~root/.ssh/config
}
  
build_cmake()
{
    cmd="curl -O https://cmake.org/files/v3.6/cmake-3.6.2.tar.gz; tar -xvzf cmake-3.6.2.tar.gz ; cd cmake-3.6.2 ; ./configure --prefix=\${HOME}/install && make && make install"
    if [ "$USER" == "root" ]
    then
       su - ${user} -c "$cmd"
    else
       bash -c "$cmd"
    fi
}

config_general()
{
  local masterip=$1
  check_root
  grep -q ^MaxStartups /etc/ssh/sshd_config || echo "MaxStartups 128:30:256" >> /etc/ssh/sshd_config

  /etc/init.d/ssh restart
  grep -q "$(cat /home/${user}/.ssh/id_rsa.pub)" /home/${user}/.ssh/authorized_keys || cat /home/${user}/.ssh/id_rsa.pub >> /home/${user}/.ssh/authorized_keys

  if [ "${IS_APT}" == "1" ]
  then
     apt-get update
     apt-get upgrade -y
     apt-get install -y ubuntu-core-libs-dev build-essential gdb binutils-doc cpp-doc gcc-5-doc autoconf automake libtool flex bison gcc-doc libgcc1-dbg libgomp1-dbg libitm1-dbg libatomic1-dbg libasan2-dbg liblsan0-dbg libtsan0-dbg libubsan0-dbg libcilkrts5-dbg libmpx0-dbg libquadmath0-dbg  make-doc gettext glibc-doc gdb-doc openmpi-bin openmpi-doc openmpi-common libopenmpi-dev netpipe-openmpi cmake valgrind csh bwm-ng  glusterfs-server attr  libxml2-dev liburcu-dev libaio-dev attr sysstat awscli nfs-common  nfs-kernel-server autofs sysstat bwm-ng smartmontools gsmartcontrol ntp traceroute
  else

    yum -y update
    yum -y groupinstall "Development Tools" "Development Libraries"
    yum -y install openmpi openmpi-devel git autofs xfsprogs sysstat
    build_cmake

  fi
}

config_nfs()
{
  grep -q '^/net' /etc/auto.master || echo "/net -hosts async" >> /etc/auto.master 
  ( grep -v '^/scratch0/export' /etc/exports ; echo "/scratch0/export        172.32.0.0/16(rw,async,no_subtree_check)" ) >> /etc/exports.tmp && mv /etc/exports.tmp /etc/exports
  /etc/init.d/nfs-kernel-server restart
  /etc/init.d/autofs restart
  /etc/init.d/nfs-kernel-server restart
  /etc/init.d/autofs restart
  rm -f /nscratch
  ln -s /net/$masterip/scratch0/export/nscratch /nscratch
  chmod 1777 /nscratch/.
}


config_scratchdirs()
{
check_root
local cpids=
local scratch_count=0
local devs=
for dev in /dev/xvd[b-z] /dev/sd[b-z]
do
  if [ -e $dev ] ; then devs="${devs} ${dev}" ; sudo umount ${dev} ; fi
done

if [ -z "${devs}" ]
then
  s=/scratch0
  mkdir -p $s/gfs_bricks/gluster_scratch $s/osd $s/export/nscratch $s/tmp
  chmod 1777 $s/tmp $s/export/nscratch
fi

mdscr=/dev/md127
if [ -d /dev/md/. ]
then
  mdscr=/dev/md/md_scratch
fi

if [ -n "$devs" ] && [ $(echo $devs | wc -w) -gt 1 ]
then
  echo "Creating $mdscr as RAID0 from $devs"
  (yes | mdadm --create --verbose $mdscr --level=0 --name=SCRATCH --raid-devices=$(echo $devs | wc -w) $devs ) && \
  mkfs.ext4 $mdscr || echo "Looks like $mdscr already exists!"
  mkdir -p /scratch0 && \
  mount $mdscr /scratch0
  s=/scratch0
  mkdir -p $s/gfs_bricks/gluster_scratch $s/osd $s/export/nscratch $s/tmp
  chmod 1777 $s/tmp $s/export/nscratch
fi

if [ ! -e $mdscr ]
then
 for dev in $devs
 do
  s=/scratch${scratch_count}
  if [ -e $dev ] && ! grep -q $s /etc/fstab
  then
    echo "configuring $dev"
    (
    umount $dev
    mkfs.ext4 -f  $dev
    echo "mounting $dev to $s"
    mkdir -p $s
    mount $dev $s
    mkdir -p $s/gfs_bricks/gluster_scratch $s/osd $s/export/nscratch $s/tmp
    chmod 1777 $s/tmp $s/export/nscratch
    ) >/tmp/init-${dev##*/}.log 2>&1 &
    scratch_count=$((scratch_count+1))
    cpids="${cpids} $!"
  fi
 done
 wait ${cpids}
fi

}

get_scratchdirs()
{
  for i in /scratch*/$1 ; do [ -d $i ] && echo $i ; done
}

config_mpi()
{
 check_root
 f=$(find /etc/ -name 'openmpi-default-hostfile')
 ( grep '#' $f ; cat  $HOSTS) > $f.tmp && mv $f.tmp $f

}



teardown_gluster()
{
  check_root
  rm -rf /gscratch/*
  umount /gscratch
  yes | gluster volume stop gluster_scratch force
  yes | gluster volume delete gluster_scratch

  gluster peer status | awk '/Hostname:/ {print $2}' | xargs -n 1 gluster peer detach
  yes | gluster system:: uuid reset
  /etc/init.d/glusterfs-server restart
}

create_gluster()
{
  check_root
  nodes=$(cat $HOSTS)

  /etc/init.d/glusterfs-server restart
  set -e
  for i in ${nodes} ; do gluster peer probe $i ; done

  num=$(echo ${nodes} | wc -w)
  scratchdirs=$(get_scratchdirs gfs_bricks/gluster_scratch)
  scratch_count=$(echo ${scratchdirs} | wc -w)

  stripes=$((num*scratch_count))
  if [ $stripes -gt 1 ]
  then
    gluster volume create gluster_scratch stripe $stripes transport tcp $(for s in ${scratchdirs} ; do for i in ${nodes}; do echo ${i}:$s ; done; done) force

    gluster volume start gluster_scratch
    #gluster volume set gluster_scratch locks.mandatory-locking optimal
    gluster volume set gluster_scratch cluster.eager-lock on
  fi
  set +e
}

mount_gluster()
{
  check_root
  scratchdirs=$(get_scratchdirs gfs_bricks/gluster_scratch)
  scratch_count=$(echo ${scratchdirs} | wc -w)
  if [ ${scratch_count} == 0 ]
  then
    config_scratchdirs
  fi
  scratchdirs=$(get_scratchdirs gfs_bricks/gluster_scratch)
  scratch_count=$(echo ${scratchdirs} | wc -w)
  if [ $scratch_count -gt 0 ]
  then
    #grep -q /gscratch /etc/fstab || echo "localhost:gluster_scratch /gscratch glusterfs defaults,_netdev,direct-io-mode=disable 0 2" >> /etc/fstab
    set -e
    mkdir -p /gscratch
   
    mount -t glusterfs -o _netdev,direct-io-mode=disable localhost:gluster_scratch /gscratch
  else
    if [ -n "$scratchdirs" ]
    then
      [ ! -d /gscratch ] || rmdir /gscratch
      ln -s $scratchdirs /gscratch
    else
      mkdir -p /gscratch
    fi
  fi
  chmod 1777 /gscratch/.
 
  set +e
  for i in /scratch/hipmer_*_data/ ; do [ -d $i ] && ln -s $i /gscratch ; done
}

initialize()
{

  local masterip=$1
  local efs=$2
  check_root
  local ME=${0##*/}
  set -e
  local pids=
  for i in $(cat $HOSTS) ; do
    echo "Initializing remote $i"
    (
    ( [ "${myip}" == "${masterip}" ] || su -l ${user} -c "rsync -av /home/${user}/hipmeraculous/contrib/$ME ${i}:" ) && \
    su -l ${user} -c "ssh ${i}  sudo ./${ME} copy_sshkeys" && \
    ssh $i /home/${user}/${ME} remote_initialize ${masterip} ${efs}) > /tmp/init-$i.log 2>&1 &
    pids="${pids} $!"
  done
  echo "Waiting for initializations"
  wait ${pids} || echo "some pids failed: $?: $(ls -1 /tmp/init-*.log)"
  echo "Done initializing"
  set +e

  config_mpi
  if [ "${USE_GLUSTER}" == "1" ]
  then
    create_gluster

    pids=
    for i in $(cat $HOSTS) ; do
      echo "mounting /gscratch on $i"
      ssh root@$i /home/${user}/${ME} mount_gluster  &
      pids="${pids} $!"
    done
    wait ${pids}
    echo "Done mounting"
  fi
  cp -p ${HOSTS} /nscratch/
  for i in $(cat $HOSTS) ; do
      traceroute -n ${i}
  done
  

}

remote_initialize()
{
  local masterip=$1
  local efs=$2
  config_general $masterip
  config_scratchdirs
  config_nfs
  if [ "${USE_GLUSTER}" == "1" ]
  then
    teardown_gluster
  fi
  if [ -n "$efs" ]
  then
    mountefs $efs
  fi
}

stopall()
{
  check_root
  for i in $(cat ${HOSTS})
  do
    ssh root@$i shutdown &
  done
  wait
}
    
  
set -x
if [ -z "$*" ]
then
  initialize ${myip} ${EFS}
  #[ -d /home/${user}/install ] || su - ${user} -c "aws s3 sync s3://hipmer-benchmarks/home-install-prereqs /home/${user} && ln -s home-install-prereqs install"
else
  $@
fi

