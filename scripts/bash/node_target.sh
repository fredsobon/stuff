#!/bin/bash

arg="${1}"
search_file="/etc/hosts"
filter=$( grep -Ei "${arg}" "${search_file}" |grep  ".frontend" |grep -v "old" |awk '{print $2}')

echo  "here are the target machines : "
echo "$filter" |sed -n 's/.frontend//p' 
count_nodes=$(echo "$filter" |sed -n 's/.frontend//p'|wc -l)
echo "hey our target's node number is $count_nodes let's go ? y / N"

echo "cssh $(echo -n "$filter" |sed 's/.frontend//p' |sed ':a;N;$!ba;s/\n/ /g') "
#echo "gimme something to eat plz !"










