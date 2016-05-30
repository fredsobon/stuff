#!/bin/bash


arg="${1}"
search_file="/etc/hosts"
filter=$(grep -Ei "${arg}" "${search_file}" |grep -iE ".frontend" |awk '{print $2}')


echo -n "$filter" |sed 's/.frontend//p'




