#!/bin/bash

# func: 

get_number () {
    # ensure "facter" is present to retrieve server serial number : 
    echo " ok ..gonna dump $node diag file "
    fact_test="$(ssh "${node}" "sudo -i which facter")"
    if [ ! -z "${fact_test}" ] ; then
        serial="$(ssh "${node}" "sudo /opt/puppetlabs/bin/facter serialnumber")"
        echo " ==== the server's serial number is ${serial} ==== "
    else 
        echo "no way ..please try to find the serial number of the server first ..facter tool is not present ..!"
        exit 3
    fi
}

gen_diag () {
    # use hp tool : ensure hpssacli is choosen first ( dedicated to recent hp proliant)
    hp_tool="$(ssh "${node}" "sudo which hpssacli")"
    if  [[ ! -z "${hp_tool}" ]]  ; then  echo "ok the hp tool used is $hp_tool"
    elif
        hp_tool="$(ssh "${node}" "sudo which hpacucli")"
        [[ ! -z "${hp_tool}" ]] ; then  echo "ok the hp tool used is $hp_tool"
    else
        echo "no tool available to generate hp diag ..."
        exit 2 
    fi
    ssh ${node} "sudo ${hp_tool} ctrl all diag file=/tmp/${serial}.zip ris=on xml=off zip=on"
}

get_diag () {
# check file gen :
file="$(ssh ${node} "ls /tmp/${serial}.zip")"
if [[ ! -z "${file}" ]]; then 
  echo " == retrieve diag file  of ${node} .... =="
  rsync -azv "${node}":${file} /tmp/
else "no way ...no file to be dumped"
fi
}

help () {
   echo "$basename $0 < servername >: this tool retrieve locally in "/tmp" folder the hp diag file generated with the serial number name prefix. Please provide the server name in param ..ensure it's present in hostfile !"
} 

# vars : 
node=$1
while getopts 'hH?' opt 
  do  
    case $opt in 
      h|H)  help ; exit 2  ;;
      help|HELP)  help ; exit 2 ;;
      *)  help ; exit 2 ;;
    esac 
  done
if  [ $# -ne "1" ] ; then 
    help
    exit 2 
elif 
! grep -qw ${node} "/etc/hosts" ; then 
    echo "ensure that the servername is present in hosts file"
    exit 3
fi 

get_number
gen_diag
get_diag

