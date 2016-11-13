#!/bin/bash

## this script aims to do some test in order to ensure unicity of records in "/etc/hosts" file record.

host_file="profile/files/hosts"
precommit_path=$(readlink  $0)
filter_path=$(dirname "$precommit_path")
RED='\033[0;31m'
NC='\033[0m'

## in order to capitalized pattern to exclude 2 files have been created each one contains text parsed by grep 
# file number one called filter1 - file number2 called filter2 

result=$(sed 's/#.*//' "$host_file" |grep -viE --file "$filter_path"/filter1 \
|tr '\t' ' ' |tr ' ' '\n' |sed '/^$/d' \
|sort -g |uniq -c |awk '$1 > 1 {print}'|sort -rn)


if [ -n "$result" ]; then 
    echo -e "${RED}Some records are present more than one time in your host file. Please check ! :${NC}"
    echo ""
    echo  "$result" |awk '{print "number => " $1  "    record name => " $2}'
    exit 1
else
    exit 0 
fi
