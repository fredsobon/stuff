#!/bin/bash

MY_PATH="`dirname \"$0\"`"

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

while getopts ":H:u:c:" opt
do
	case "$opt" in
	H) host=$OPTARG ;;
	u) user=$OPTARG ;;
	c) check=$OPTARG ;;
	esac
done

IFS=$(echo -en "\n")
resultat=$(ssh -T -l $user $host < $MY_PATH/$check)
echo $resultat
unset IFS

if grep -q CRITICAL <<< $resultat 
then
	exit $STATE_CRITICAL
fi

if grep -q WARNING <<< $resultat
then
        exit $STATE_WARNING
fi

if grep -q DEPENDENT <<< $resultat
then
        exit $STATE_DEPENDENT
fi

if grep -q UNKNOWN <<< $resultat
then
        exit $STATE_UNKNOWN
fi

if grep -q OK <<< $resultat
then
        exit $STATE_OK
fi

exit $STATE_UNKNOWN
