#! /bin/bash
cd /home/boogie/Documents/work/repos_work/puppet

# retrieve the current branch name of the repo :
git_br=$(git rev-parse --symbolic-full-name --abbrev-ref HEAD)

echo "current branch is $git_br"

if [ ${git_br} == "production" ]
 then echo "ok  puppet prodcution is the current branch..."
else        
 git checkout production
fi 
echo " .... update hosts files ...."
sudo cat /home/boogie/Documents/work/repos_work/puppet/profile/files/hosts > /etc/hosts
