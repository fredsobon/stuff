#!/bin/bash

repos_dir="/home/boogie/Documents/work/repos"


cd $repos_dir
echo -n "list of repos : " ; ls ${repos_dirs}
for repos in ${repos_dir}/*
do
            cd $repos ; echo " repo =>  $repos ...is being updated .... " 
            git pull
            cd ..
done
# post up to be updated we need a fresh host file :
sudo cp /home/boogie/Documents/work/repos/puppet/profile/files/hosts  /etc/hosts
# post to be updated in dashboard urls :
sudo cp /home/boogie/Documents/work/repos/exploit-tools/dashboard/index.html /home/boogie/Documents/dashboard/index.html 


