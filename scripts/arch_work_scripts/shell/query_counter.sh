#!/bin/bash
#set -x
 
##var :
dnsearch=$(which dns_search)
idx_list=$(${dnsearch} -1 -g ^index..*.prod.*.e-merchant.net)
date_folder=$(date +%F)
dst_folder="pertimm_counter-${date_folder}"
zipcmd=$(which zip) 
#func :
 
use() {
cat <<EOF
    Usage : $(basename $0) - quick resume :
- Does not need args ...
- we retrieve our target machines with dns_search, then for each server , we list all projects. 
- we process with pertimm account the dedicated commands to catch stats from search, suggest and rules.
- we then copy the generated files in a specific folder.
- we then delete created files from server. 
- finally zip is created : ready to be sent to pertimm's team.
EOF
}
 
check_dns() {
which dns_search 
	if [ "$?" -ne 0 ]
    then
    echo "dns_search is mandatory for this job ... please check ..."
	exit 1
    fi
}

check_zipcmd() {
which zip
	if [  "$?" -ne 0 ]
	then
	echo "zip is mandatory for this job ... please check ..." 
	exit 2 
	fi
}

 
grep_dst() {
echo "stats gonna be downloaded in the directory of your choice : "
read dst
cd $dst
    if [ -e ${dst_folder} ] 
    then echo " Be carreful ${dst_folder} already exist ..and maybe shouldn't be (re)created ...please have a look."
    exit 3 
    fi
 
mkdir ${dst_folder}
}
 
control_c() {
# run if user hits control-c
  echo -en "\n*** Ouch! Exiting ***\n"
  exit $?
}
 
 
while getopts ":h" opt; do
  case $opt in
    h)
     use
     exit 4
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
     exit 5
      ;;
  esac
done
 
check_dns
check_zipcmd

grep_dst
# trap keyboard interrupt (control-c)
trap control_c SIGINT
 
########
##Main##
########
 
for serv in $idx_list
do
    for proj in $(ssh ${serv} "ls /opt/pertimm/projects ")
        do echo "=== start processing for * $proj * project ===" 
        ssh $serv "su - pertimm -c \"cd /opt/pertimm/projects/${proj}/apps 
        ./pdk counter aggregate -i search -f ${proj}_search.json
        ./pdk counter aggregate -i search -f ${proj}_suggest.json
        ./pdk counter aggregate -i search -f ${proj}_rules.json\" "
            for files in $(ssh ${serv} "ls /opt/pertimm/projects/${proj}/apps/*.json")
                do 
                scp ${serv}:${files} ${dst_folder}
                ssh ${serv} "rm $files"
            done
    done
done
 
$zipcmd -r  ${dst_folder}.zip ${dst_folder}
