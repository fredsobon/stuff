#!/bin/sh

# var 
node="/usr/bin/node"
folder="/home/boogie/fold"


## browse directory and check js syntax with node lint : 

for dir in ${folder}/*
do 
  if [ -d "$dir" ]; then 
  cd $dir
  echo "===== $(basename $dir) =====" 
  for j in $(ls *.js) 
    do 
      echo " >>>>>>> $j  " ; $node --check $j 
    done 
    cd .. 
  fi 
done
