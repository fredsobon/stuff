#!/bin/bash

arg="${1}"
search_file="/etc/hosts"
filter=$( grep -Ei "${arg}" "${search_file}" |grep  ".frontend" |grep -v "old" |awk '{print $2}')

echo  "here are the target machines : "
echo "$filter" |sed -n 's/.frontend//p' 
echo "let's go :"
 

cssh $(echo -n "$filter" |sed 's/.frontend//p' |sed ':a;N;$!ba;s/\n/ /g') 









