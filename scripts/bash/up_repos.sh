#!/bin/bash

# main goal update  ressources : git repos, hosts file and update inventory groupes.

repos_dir="/home/boogie/Documents/work/repos_work/"
job_host_file="/home/boogie/Documents/work/repos_work/puppet/profile/files/hosts"
dash_index="/home/boogie/Documents/work/repos_work/exploit-tools/dashboard/index.html"

for  i in $(find ${repos_dir} -iname  ".git" |sed -e 's/\(.*\).git$/\1/')
do  
  echo "== $i ==" 
  cd $i
        if [[ $(basename "$i") = "puppet" ]] || [[ $(basename "$i") = "hiera" ]]; then
            branch=$(git branch | grep \* | cut -d ' ' -f2)
            if  [ "$branch"  != "production" ]; then
            echo "Beware =>  $branch is the curent branch in $i repo ! Let's move in production "
                git checkout production
                git pull 
            fi
        fi  
  git pull 
  cd - 
done     

echo " let's update dashboard .."
sudo cat ${dash_index} >/home/boogie/Documents/work/dashboard/index.html

echo " let's update the host_file too ..."
sudo bash -c "cat ${job_host_file}  > /etc/hosts"

echo " ok now gonna update ansible inventory files for each environment.."
/usr/local/bin/build_dev_inventory.sh
/usr/local/bin/build_preprod_inventory.sh
/usr/local/bin/build_prod_inventory.sh
/usr/local/bin/build_recette_inventory.sh

