#!/bin/bash

## this script aims to do some test in order to ensure unicity of records in "/etc/hosts" file record.
host_file="/etc/hosts"

## in order to capitalized pattern to exclude 2 files have been created each one contains text parsed by grep 
# file number one called filter1 - file number2 called filter2 

result=$(cat ${host_file} |grep -viE --file filter1 \
|tr '\t' ' ' |tr ' ' '\n' |sed '/^$/d' \
|sort -g |uniq -c |grep -Evi --file filter2 |sort -rn)


if [ -n "$result" ]; then 
    echo "Some records are present more than one time in your host file. Please check ! : "
    echo ""
    echo  "$result" |awk '{print "number => " $1  "    record name => " $2}'
    exit 1
else
    exit 0 
fi
