#!/bin/bash

## this script aims to do some test in order to ensure unicity of records in "/etc/hosts" file record.
host_file="/etc/hosts"



result=$(cat ${host_file} |grep -viE "^#|test|:|eof|\[temp]|temporaires|spare" \
|tr '\t' ' ' |tr ' ' '\n' |sed '/^$/d' \
|sort -g |uniq -c |grep -Evi "      1|#|switch|san|irac|bessiere|ulis"|sort -rn)


if [ -n "$result" ]; then 
    echo "Some records are present more than on time in your host file. Please check !"
    echo " $result"
    exit 1
else
    exit 0 
fi
