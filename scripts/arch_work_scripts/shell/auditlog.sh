#!/bin/bash
# vim: ts=4 sw=4

####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################


# Author: dlarquey

# script to audit process, disk and network activity 
# Extra commands for auditlog are in the file auditlog.extra


LOG_DIR=/var/log/auditlog

# optional extra command file
scriptname=$(basename $0)
EXTRA_COMMAND_FILE=$(dirname $0)/${scriptname%.*}.extra

# log files
MAIN_LOG_FILE=${LOG_DIR}/audit.log
ERROR_LOG_FILE=${LOG_DIR}/audit.err
BASE_LOG_FILE=${LOG_DIR}/audit_base.log
PROC_LOG_FILE=${LOG_DIR}/audit_proc.log
NET_LOG_FILE=${LOG_DIR}/audit_net.log
EXTRA_LOG_FILE=${LOG_DIR}/audit_extra.log

LOCK_FILE=/var/lock/${scriptname%.*}.lock
LIMIT_SIZE=50000000 #50M


#################
### Functions ###
#################

function my_exit() {
    [ -f $LOCK_FILE ] && rm -f $LOCK_FILE
}


function truncate_logfiles {
    logfile=$1
    [ ! -f $logfile ] && return 1;
    last=$(date +%Y%m%d --date=@$(stat --format=%Y $logfile))
    if [ $TODAY -gt $last ] ; then
            nice -n 19 gzip -f --fast $logfile
            echo -n >$logfile
            echo "[$(date)] logfile was zipped: $logfile" >>$MAIN_LOG_FILE
    fi

    [ $(stat --format=%s $logfile 2>/dev/null) -ge $LIMIT_SIZE ] && { echo -n >$logfile; echo "[$(date)] Max size reached ($LIMIT_SIZE) for logfile: $logfile" >>$MAIN_LOG_FILE; }
}


### Base commands ###

function set_commands {

    CMD[${#CMD[@]}]="uptime"
    CMD[${#CMD[@]}]="free -m"
    CMD[${#CMD[@]}]="top -b -n 1"
    CMD[${#CMD[@]}]="ps axf -o user,pid,ppid,state,start,time,%cpu,%mem,size,vsize,rss,wchan=WIDE-WCHAN-COLUMN,command"

    CMD[${#CMD[@]}]="mpstat -P ALL"
    CMD[${#CMD[@]}]="vmstat 1 3"
    CMD[${#CMD[@]}]="iostat -x 1 3"

    # proc
    CMD_PROC[${#CMD_PROC[@]}]="cat /proc/meminfo"
    CMD_PROC[${#CMD_PROC[@]}]="cat /proc/zoneinfo"
    CMD_PROC[${#CMD_PROC[@]}]="cat /proc/interrupts"
    CMD_PROC[${#CMD_PROC[@]}]="cat /proc/stat"
    CMD_PROC[${#CMD_PROC[@]}]="cat /proc/vmstat"
    
    # Net
    CMD_NET[${#CMD_NET[@]}]="netstat -s"
    CMD_NET[${#CMD_NET[@]}]="netstat -laputen|grep -v TIME_WAIT"

    [ -f $EXTRA_COMMAND_FILE ] && {
        [ $(stat --format=%u $EXTRA_COMMAND_FILE) != '0' ] && { echo "Extra command file must belong to root: $EXTRA_COMMAND_FILE" >>$MAIN_LOG_FILE; exit 1; }
        [ $(stat --format=%a $EXTRA_COMMAND_FILE) != '644' ] && { echo "Extra command file must have 644 owner rights: $EXTRA_COMMAND_FILE" >>$MAIN_LOG_FILE; exit 1; }
        echo "[$(date)] Reading extra command file: $EXTRA_COMMAND_FILE" >>$MAIN_LOG_FILE
        . $EXTRA_COMMAND_FILE
    }
}





############
### MAIN ###
############

[ -f $LOCK_FILE ] && { echo "Error: existing lock file" >&2; exit 1; }
[ $(id -u) != '0' ] && { echo "Must be root to do that!"; exit 0; }

trap my_exit EXIT
touch $LOCK_FILE

sleep 125

start=$(date +%s)
TODAY=$(date +%Y%m%d --date=@$start)

[ ! -d $LOG_DIR ] && mkdir -p $LOG_DIR

truncate_logfiles $MAIN_LOG_FILE
truncate_logfiles $ERROR_LOG_FILE
truncate_logfiles $BASE_LOG_FILE
truncate_logfiles $PROC_LOG_FILE
truncate_logfiles $NET_LOG_FILE
truncate_logfiles $EXTRA_LOG_FILE

set_commands
exec 2>$ERROR_LOG_FILE
echo "[$(date)] Launching audit of system activity" >>$MAIN_LOG_FILE

exec 1>>$BASE_LOG_FILE
echo -e "\n<<<<<<<<<<<<<<<<< START DATE: $(date +"%Y/%m/%d %H:%M:%S") <<<<<<<<<<<<<<<<<"
for cmd in "${CMD[@]}"; do
    bin=$(echo $cmd|awk '{print $1'})
    which $bin >/dev/null && echo "### [$(date +"%Y/%m/%d %H:%M:%S")] $bin : $cmd ###" && eval nice -n 15 $cmd
    echo
done
echo ">>>>>>>>>>>>>>>>> STOP DATE: $(date +"%Y/%m/%d %H:%M:%S") >>>>>>>>>>>>>>>>>>"

# proc
exec 1>>$PROC_LOG_FILE
echo -e "\n<<<<<<<<<<<<<<<<< START DATE: $(date +"%Y/%m/%d %H:%M:%S") <<<<<<<<<<<<<<<<<"
for cmd in "${CMD_PROC[@]}"; do
        bin=$(echo $cmd|awk '{print $1'})
        which $bin >/dev/null && echo "### [$(date +"%Y/%m/%d %H:%M:%S")] $bin : $cmd ###" && eval nice -n 15 $cmd
        echo
done
echo ">>>>>>>>>>>>>>>>> STOP DATE: $(date +"%Y/%m/%d %H:%M:%S") >>>>>>>>>>>>>>>>>>"

# net
exec 1>>$NET_LOG_FILE
echo -e "\n<<<<<<<<<<<<<<<<< START DATE: $(date +"%Y/%m/%d %H:%M:%S") <<<<<<<<<<<<<<<<<"
for cmd in "${CMD_NET[@]}"; do
        bin=$(echo $cmd|awk '{print $1'})
        which $bin >/dev/null && echo "### [$(date +"%Y/%m/%d %H:%M:%S")] $bin : $cmd ###" && eval nice -n 15 $cmd
        echo
done
echo ">>>>>>>>>>>>>>>>> STOP DATE: $(date +"%Y/%m/%d %H:%M:%S") >>>>>>>>>>>>>>>>>>"

# extra
if [ -f $EXTRA_COMMAND_FILE ]; then
    exec 1>>$EXTRA_LOG_FILE
    echo -e "\n<<<<<<<<<<<<<<<<< START DATE: $(date +"%Y/%m/%d %H:%M:%S") <<<<<<<<<<<<<<<<<"
    for cmd in "${CMD_EXTRA[@]}"; do
            bin=$(echo $cmd|awk '{print $1'})
            which $bin >/dev/null && echo "### [$(date +"%Y/%m/%d %H:%M:%S")] $bin : $cmd ###" && eval nice -n 15 $cmd
            echo
    done
    echo ">>>>>>>>>>>>>>>>> STOP DATE: $(date +"%Y/%m/%d %H:%M:%S") >>>>>>>>>>>>>>>>>>"
fi


echo "[$(date)] audit is finished (duration: $(($(date +%s) -$start)) sec)" >>$MAIN_LOG_FILE

