#!/bin/bash


target="$2"



while getopts "abish:" flag
do
        case $flag in

                a) grep -E "${target}.*.admin" /etc/hosts |grep -vE "(^#|old)"
                ;;
                b) grep -E "${target}.*.backup" /etc/hosts |grep -vE "(^#|old)"
                ;;
                i) grep -E "${target}.*.ilo" /etc/hosts |grep -vE "(^#|old)"
                ;;
                s) grep -E ${target} /etc/hosts |grep -vE "(^#|old)" |awk '{print  $3}'
                ;;
		h) echo "usage $(basename $0) <option> Host. This script has to be used with one of the following option   -a : retrieve admin host | -b :retrieve backup host | -i retrieve ilo host | -s : retrieve shortname  host "
		;;
		*|[:blank:]) echo " please use a valided arg : <a> <b> <i> <s> or <-h> : for usage"
		
        esac
done

