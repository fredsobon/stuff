#!/bin/bash


repos_dir="/home/boogie/Documents/work/repos_work/"
job_host_file="/home/boogie/Documents/work/repos_work/puppet/profile/files/hosts"



for rep in $(ls $repos_dir)
do
echo $rep	; cd "${repos_dir}/"${rep} ; echo " === $rep update starts ....===" ; git pull ; cd ..
done

echo " let's update the host_file too ..."
sudo cat ${job_host_file}  > /etc/hosts

