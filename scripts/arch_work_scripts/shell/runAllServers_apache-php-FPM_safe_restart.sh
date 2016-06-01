#!/bin/bash

# vim: set ft=sh sw=4 et ts=4

# This script is used to do a safe restart of Apache/PHP FPM on all real WEB servers one by one sequentially.
# It must be run from the staging server only. (the root ssh key of the staging server is provided all over the cluster)
# for each real server, it runs remote script: /usr/local/e-merchant/bin/apache-php-FPM_safe_restart.sh who is in charge of restarting services safely

# If an error occured on remote script, then the treatment is canceled and an email requesting checks is sent.


LOCK_FILE=/var/lock/$(basename $0|sed s/.sh$//).lock
LIST_HOSTS=/usr/local/etc/liste_ip

HOSTNAME=$(hostname -f)
POOL=$(echo $HOSTNAME|cut -d'.' -f3|tr '[a-z]' '[A-Z]')
HOST=$(echo $HOSTNAME|cut -d'.' -f1|tr '[a-z]' '[A-Z]')

# Remote script
RESTART_SCRIPT=/usr/local/e-merchant/bin/apache-php-FPM_safe_restart.sh

# SSH
SSH_OPTS="-i /root/.ssh/id_dsa -o BatchMode=yes -o ConnectTimeout=30 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ConnectTimeout=30 -o PubkeyAuthentication=yes -o PasswordAuthentication=no -o PreferredAuthentications=publickey"

# Email
EMAIL="it.prod.admin@pixmania-group.com"
SUBJECT_PREFIX="[FRONT_RESTART][$POOL]"
SUBJECT="Apache/PHP FPM"

[ "$1" == '--cron' ] && SUBJECT_PREFIX="[CRON]${SUBJECT_PREFIX}"
SIGNATURE="

~~~
This email is sent by script : $0 running on host <$HOSTNAME>"

restart_done_counter=0
tmpOutputFile=
tmpStatusFile=



#################
### Functions ###
#################

function log {
    echo "[$(date)][$HOSTNAME][PID=$$] $@"
}

function log_and_exit_withouterror {
    echo "[$(date)][$HOSTNAME][PID=$$] $@"
    exit 0
}

function log_and_exit_witherror {
        echo "[$(date)][$HOSTNAME][PID=$$] ERROR: $@" >&2
        exit 1
}

function myExit {
    rm -f $LOCK_FILE
    [ -f $tmpOutputFile ] && rm -f $tmpOutputFile
    [ -f $tmpStatusFile ] && rm -f $tmpStatusFile
}



############
### MAIN ###
############

[ $(id -u) -eq 0 ] || log_and_exit_witherror "Must be root"
[ -f $LOCK_FILE ] && log_and_exit_witherror "Lock file is present: $LOCK_FILE. Abort."
[ -f $LIST_HOSTS ] || log_and_exit_witherror "Missing hosts list file: $LIST_HOSTS"
[ $HOST == 'WEB00' ] || log_and_exit_witherror "This server is not a staging WEB server"

if [ "x$1" != 'x--cron' ]; then
    echo "Restart $SUBJECT services on pool: $POOL"
    echo -n "Do you wan to continue (y/n) : "
    read
    [ "x$(echo $REPLY|tr '[a-z]' '[A-Z]')" != "xY" ] && exit 1
fi


trap myExit EXIT
touch $LOCK_FILE

tmpStatusFile=$(tempfile)
for host in $(cat $LIST_HOSTS); do
    echo ">>>>>> [$(date)] POOL=$POOL Restart $SUBJECT on host: $host >>>>>>"
    echo -en "[$(date)] $host\t" >>$tmpStatusFile

    ping -c 3 $host >/dev/null
    if [ $? -ne 0 ]; then
        echo "[$(date)][PID=$$] ERROR: Host: $host seems to be offline. Cancel this host." >&2
        echo 'Error: OFFLINE' >>$tmpStatusFile
        continue
    fi

    tmpOutputFile=$(tempfile)

    ssh $SSH_OPTS root@$host "[ -x $RESTART_SCRIPT ] && $RESTART_SCRIPT" 2>$tmpOutputFile
    ret=$?

    [ -s $tmpOutputFile ] && cat $tmpOutputFile
    echo "<<<<<< [$(date)] return status: $ret <<<<<<"


    if [ $ret -ne 0 ]; then
        echo 'Error: FAIL' >>$tmpStatusFile
        echo "[$(date)][PID=$$] ERROR: An error occured during the restart of $SUBJECT on host: <$host>. Sending error mail to: <$EMAIL>" >&2

        mail -s "$SUBJECT_PREFIX[ERROR] $host: ERROR during the restart of $SUBJECT services" $EMAIL <<EOM
An error occured during restart of $SUBJECT services on host: <$host> (script: $RESTART_SCRIPT)
Automatic restart of $SUBJECT services on others real servers is canceled.

PLEASE CHECK services on this host. Service might be offline after this failure.

+ The remote return status code is : $ret
+ Remote Error message:
$(cat $tmpOutputFile)

+ $SUBJECT services have been restarted on following hosts:
$(cat $tmpStatusFile)
$SIGNATURE
EOM

    # Exit with error
    exit 1

    else
        echo 'OK' >>$tmpStatusFile
        let restart_done_counter+=1
    fi
done


# Test if services have been successfully restarted on all hosts
if [ $restart_done_counter -eq $(wc -l $LIST_HOSTS| awk '{print $1}') ]; then
    # All is fine
    echo -e "\nALL IS FINE: The automatic restart of $POOL $SUBJECT on all real servers is successfully done.\n"
    mail -s "$SUBJECT_PREFIX Automatic safe restart of $POOL $SUBJECT services: OK" $EMAIL <<EOM
+ $SUBJECT services have been successfully restarted on following hosts:
$(cat $tmpStatusFile)
$SIGNATURE
EOM

else
    # One error occured
    echo "[$(date)][PID=$$] ERROR: The restart of all $POOL $SUBJECT real servers seems to have failed. Sending error mail to: <$EMAIL>" >&2
    mail -s "$SUBJECT_PREFIX $host: ERROR during the restart of $SUBJECT services" $EMAIL <<EOM
One or more real servers of the pool can't been restarted (seems to be offline). Please check.

+ $SUBJECT services have been restarted on following hosts:
$(cat $tmpStatusFile)
$SIGNATURE
EOM

fi

