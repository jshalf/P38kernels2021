#!/bin/bash

set -e
set -x
for i in *.log
do
   if [ -f $i ]
   then
     aws s3 cp $i s3://hipmer-benchmarks/Nov2016/$i && rm $i
   fi
done

cd $SCRATCH/latest_output
d=$(pwd -P)
d=${d##*/}
cd ..
tar -cvzf $d.tar.gz $d/*.log 
aws s3 cp $d.tar.gz s3://hipmer-benchmarks/Nov2016/$d.tar.gz

