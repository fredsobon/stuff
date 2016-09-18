#!/bin/bash

## mandatory :
default_temp_file="/tmp/$(date +%F)-inventory.csv"
default_temp_dir="/tmp/"
converter=$(which xlsx2csv)

## functions :
process_file () {

# first step : retrieve inventory file and prepare his uses if this file is too old for you :
echo "Give me the inventory file with his full path to eat : "
read original

cp ${original} "${default_temp_dir}/" && cd ${default_temp_dir}
pwd
echo "$default_temp_file ; $default_temp_dir ; $original"

echo "let's gonna process ...."

echo "${converter}  "$original" "$default_temp_file""
${converter}  "$original" "$default_temp_file"

pwd && ls -lah

}
# raw research : 
node_search () {
grep -ri $node $default_temp_file 
}

if [ ! -f "$default_temp_file" ]; then 
echo "your inventory seems to be a little bit old ..."
process_file
fi

# node search inject the node name and retrieve infos :

echo "now please provide the node's name you would like to retrieve infos : "
read node
node_search

 
#grep -ri "zinflogidxpay01b" 1474207153.csv  |awk -F, 'BEGIN {print "Datacenter Location","=", "node number","=", "rack number","=", "position in rack", "=", "hostname" } {print $1, "=", $2, "=", $3, "=", $4, "=", $9}
 

#echo ""$temp_dir" -rf"

