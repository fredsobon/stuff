#!/bin/bash

MY_PATH="`dirname \"$0\"`"

case $1 in
        filer12vit)	ssh -l ngermain filer12.storage.common.prod.vit.e-merchant.net < $MY_PATH/zfs_check_activity;;
        filer13vit)	ssh -l ngermain filer13.storage.common.prod.vit.e-merchant.net < $MY_PATH/zfs_check_activity;;
        filer12std)	ssh -l ngermain filer12.storage.common.prod.std.e-merchant.net < $MY_PATH/zfs_check_activity;;
        filer13std)	ssh -l ngermain filer13.storage.common.prod.std.e-merchant.net < $MY_PATH/zfs_check_activity;;
	all)		for i in $(cat $MY_PATH/zfs | grep -v "#")
			do
			        echo $i
			        ssh -l ngermain $i < $MY_PATH/zfs_check_activity
			done;;
        *)		echo "choix possibles filer12vit|filer13vit|filer12std|filer13std|all"
esac
