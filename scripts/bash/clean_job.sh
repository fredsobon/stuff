#!/bin/bash 

del_lock=$1

ssh node "ls -l /data/alerts/jobs/"
job=$(ssh node "ls  /data/alerts/jobs/")
if [ -z "${job}" ]

then echo "no job to be cleaned ....ciao !" ; exit 1
fi


read -p "locked jobs to delete : Y/N ?" ans
        case $ans in 
                y|Y|yes) echo "$job"
                         read -p "please gimme a job to del : " del_lock                
                         ssh node "rm /data/alerts/aborted_jobs/$del_lock"
                        ;;
                n|N|no) echo "bye"
                        ;;
        *) echo "hey gimme Y or N ..plz"
        esac

