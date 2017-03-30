#!/bin/bash

# check space used on nodes provided in args
# set -x

# thresholds :

warning=65
critical=80

# checks for  arg(s) 

if [ $# -lt 1 -o "$1" == "" ];then
        echo "usage: $0 adresse_bigip"
        exit 1
fi

# main job : 

for node in $*
do 
    #ssh -l root -i ~/.ssh/id_dsa -o StrictHostKeyChecking=no $1 "df -P" |grep '^/dev' |awk '{print $6, $5}' |sed 's/%//' |while read space part
    ssh  boogie@$1 "df -P" |grep '^/dev' |awk '{print $5, $6}' |sed 's/%//' |while read space part
	do 

        # testing values : 
        if [ "$space" -ge "$critical" ]; then
		    res=$?
            echo "critical : $part is full for $space on $node "
			#echo "$res"
            exit 2
        elif
           [ "$space" -ge "$warning" -a "$space" -lt "$critical" ]; then
            res=$?
			echo "warning : $part is full for $space on $node "
			exit 1
			#echo "$res"
        else
            echo "tutti va bene"
			exit 0
        fi
        done
done


