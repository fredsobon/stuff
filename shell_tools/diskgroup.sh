#!/bin/bash

tmpfile=/tmp/luns
multipath -ll | sed '/([0-9a-f]\{33\})/ i \\' $inputfile | awk 'BEGIN {RS=""; FS="\n"} {for(i=3; i<=NF; i++) {print $1,$2,$i}}'| egrep -v "status" | awk -F " " '{print $1";"$14}' > $tmpfile
for i in $(cat $tmpfile | cut -d "_" -f 1,2 | sort -t "_" -k 2 | uniq)
        do
          var=$(cat $tmpfile|grep $i|cut -d ";" -f 2)
          echo $i $var;
done
