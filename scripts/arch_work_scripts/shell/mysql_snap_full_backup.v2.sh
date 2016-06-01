#!/bin/bash

# Author: David Larquey, <d.larquey@pixmania-group.com>
# Last modified: Tue Aug 25 15:08:04 CEST 2015

# ChangeLog
# 2015/08/25 : add the management of a pool
# /!\ We can have only one pool per server
# The pool id is fixed the FQDN (the second digit of the short name beginning by the end)

# --- SVN  properties ---
# $HeadURL: http://svn.e-merchant.net/svn/norel-dba/dbawork_mysql/shell/cron/mysql_snap_full_backup.v2.sh $ $Revision: 985 $
# $Author: d.larquey $ $Date: 2015-08-25 15:10:45 +0200 (mar. 25 août 2015) $


# Summary:
# This script takes a LVM snapshot of the Mysql volume
# Then, it performs a full backup of all databases in a gzipped tar archive to a destination directory
# In SHARED mode, only one slave is elected to perform the backup


export PATH=$PATH:/usr/bin

DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=${HOSTNAME:=$(hostname -s)}

# LVM

# LVM snap
SNAP_SIZE_DEFAULT=10g
LVM_SNAP_NAME=mysqlsnapshot01
SNAP_MOUNTDIR=/tmp/mysqlsnapshot01

# Mysql
MYSQL_POS_FILENAME=backup-mysql_${DATE}.pos
MYSQL_POS_FILE=/tmp/$MYSQL_POS_FILENAME
MYSQL_CONFIG_FILE=/etc/mysql/my.cnf
MYSQL_CONFIG_FILE_COPY_FILENAME=backup-mysql_${DATE}.cnf

# Backup
BACKUP_FILE_PREFIX="MYSQL_BACKUP_FULL"
RETENTION_DAYS_DEFAULT=5

# MISC
BIN_PV=$(which pv 2>/dev/null)


# number of seconds to wait for a slave
SHARED_WAIT_DEFAULT=10
RANDOM_WAIT_TIME=5




#################
### Functions ###
#################

function printSyntax() {
cat <<EOS

Syntax:
$(basename $0) [-g VG] [-l Mysql_volume] [-d Destination] [-s SnapSize] [-r Retention (days)] [-L Bandwith limit (MB/S)] [-S] [SHARED Mode Options]


Prerequisites

All MySQL datas (datas + binlogs + relaylogs)  must be on a same LVM volume

Options

    -g  Volume group for the source volume
    -l  Logical volume name for the local SOURCE (MySQL datadir to backup). Default is '$LVM_SOURCE'
    -s  Snapshot size. Default is ${NAP_SIZE_DEFAULT}
    -d  Destination directory

    -L  Bandwith limit to write the backup archive on the destination (in MB/sec)
    -r  Retention of backup in the destination (in days). Default is $RETENTION_DAYS_DEFAULT
    -S  standalone: bypass the master/slave status check. Only available when the shared mode is disabled

SHARED MODE: Options for a shared destination storage
    -X  Enable the shared mode. The destination directory is a volume shared by all cluster nodes. Try to elect a slave for performing the backup
    -W  Wait time (second) to choose among one slave. Need "-S"
    -F  In a clustered environment. If any slave is found, perform the backup from a Master. Need "-S"

EOS
}

function LogError() {
        echo -e "[$(date)] $@" >&2
        exit 1
}

function Log() {
        echo -e "[$(date)] $@"
}

function is_integer() {
    echo $1|egrep -q '^-?[0-9]+$'
    return $?
}

function is_block_device() {
    [ -b $1 ] || LogError "Wrong LVM block device: $1"
}

function get_device_mountdir {
        local dev="$1"
        awk "(\$1==\"$dev\") {print \$2}" /proc/mounts 2>/dev/null
}

function get_mounted_device {
        local mnt="$1"
        awk "(\$2==\"$mnt\") {print \$1}" /proc/mounts 2>/dev/null
}

function check_lvm() {
    /sbin/lvs --noheadings $1 &>/dev/null ||  LogError "The lvm volume does not exist: $1"
}

function check_args() {
[ -z "$ARG_LVM_VG" ] && LogError "Missing Volume Group"
[ -z "$ARG_LVM_SRC" ] && LogError "Missing Mysql volume name"

    /sbin/vgs --noheadings -o vg_name $ARG_LVM_VG &>/dev/null || LogError "Wrong Volume Groupe: $ARG_LVM_VG"
    check_lvm $LVM_MYSQL
    echo $SNAP_SIZE|egrep -qi '^[0-9]+(m|g)$' || LogError "Wrong snapshot size: $SNAP_SIZE"
    is_integer $ARG_RETENTION_DAYS || LogError "Wrong local retention: $ARG_RETENTION_DAYS"
    if [ -n "${ARG_BANDWITH_WRITE_LIMIT_M}" ]; then
        is_integer ${ARG_BANDWITH_WRITE_LIMIT_M} || LogError "Wrong bandwith limit: ${ARG_BANDWITH_WRITE_LIMIT_M}"
    fi

    [ $ARG_SHARED -eq 1 ] && [ $ARG_STANDALONE -eq 1 ] && LogError "Can't bypass master check in shared mode"
    [ -z "$ARG_DEST" ] || [ ! -d $ARG_DEST ] && LogError "Destination directory is missing or does not exist"

}


function create_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        mnt_snap=$(get_device_mountdir $LVM_SNAP)
        [ -n "$mnt_snap" ] && LogError "The snapshot $LVM_SNAP_NAME is already mounted on $mnt_snap"
        LogError "The snapshot $LVM_SNAP_NAME already exists!"
    fi

    # Create the snapshot
    SNAP_CMD="flush tables with read lock; system sync; system /sbin/lvcreate --size $SNAP_SIZE --snapshot /dev/$ARG_LVM_VG/$ARG_LVM_SRC --name $LVM_SNAP_NAME; show slave status\G; unlock tables;"
    Log "Taking the LVM snapshot by locking tables: $LVM_SNAP_NAME"
    mysql -e "$SNAP_CMD" >$MYSQL_POS_FILE
    return $?
}

function mount_snap() {
    /sbin/lvs $LVM_SNAP &>/dev/null || LogError "Missing snapshot!"
    case "$MYSQL_FS_TYPE" in
        ext4) MNT_OPTS='ro' ;;
        xfs) MNT_OPTS='ro,nouuid' ;;
        *) MNT_OPTS='ro' ;;
    esac

    local CMD="mount -t $MYSQL_FS_TYPE -o $MNT_OPTS $LVM_SNAP $SNAP_MOUNTDIR/mysql"

    local mnt=$(get_mounted_device $SNAP_MOUNTDIR)
    [ -n "$mnt" ] && LogError "A volume is already mounted on the snapshot mountdir: $SNAP_MOUNTDIR"

    if [ -d  $SNAP_MOUNTDIR ]; then
        echo "The snapshot mountpoint already exists: $SNAP_MOUNTDIR"
        rmdir $SNAP_MOUNTDIR
        [ $? -eq 0 ] || LogError "Can't delete the mountpoint"
    fi
    mkdir -p $SNAP_MOUNTDIR/mysql
    Log "Mounting the snapshot on $SNAP_MOUNTDIR/mysql"
    Log "Runnnig: $CMD"
    eval $CMD
    return $?
}

function do_before_snap() {
    Log "[Pool:${POOL_ID}] Copying position and config files"
    cp -a $MYSQL_CONFIG_FILE $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME
}

function do_local_archive() {
    Log "[Pool:${POOL_ID}] Creating the archive: $BACKUP_FILE ..."
    bandwith_limit=""
    [ -n "${ARG_BANDWITH_WRITE_LIMIT_M}" ] && bandwith_limit="-L ${ARG_BANDWITH_WRITE_LIMIT_M}m"

    # performing the backup
    CMD="time tar -cvf - -C $(dirname $MYSQL_POS_FILE) $MYSQL_POS_FILENAME -C $SNAP_MOUNTDIR . | gzip --stdout --verbose --fast | ${BIN_PV} ${bandwith_limit}"
    Log "Running: $CMD"
    eval $CMD >${BACKUP_FILE}.INCOMPLETE
    ret=$?

    if [ $ret -eq 0 ]; then
        Log "[Pool:${POOL_ID}] The archive was succesfully created: ${BACKUP_FILE}"
        mv ${BACKUP_FILE}.INCOMPLETE ${BACKUP_FILE}
        Log "[Pool:${POOL_ID}] Purging old local archives (Retention: $ARG_RETENTION_DAYS days)"

        local retention_minutes=$(($ARG_RETENTION_DAYS*1440 - (($(date +%s)-$ts_start)/60)))
        find ${ARG_DEST}/${PLATFORM} -type f -mmin +$retention_minutes -name ${BACKUP_FILE_PREFIX}\*.tgz -exec rm -vf {} \;
    else
            if [ -f ${BACKUP_FILE}.INCOMPLETE ]; then
                ls -l $backup_file
                Log "Removing the incomplete archive: ${BACKUP_FILE}.INCOMPLETE"
                rm -f ${BACKUP_FILE}.INCOMPLETE
            fi
            LogError "[Pool:${POOL_ID}] The archive was not succesfully created. Backup has failed. Please check."
    fi
    find ${ARG_DEST}/${PLATFORM} -type f -mmin +$retention_minutes -name ${BACKUP_FILE_PREFIX}\.INCOMPLETE -exec rm -vf {} \;
}

function release_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        Log "Snap usage:"
        /sbin/lvs $LVM_SNAP
        Log "Unmounting the snapshot: $LVM_SNAP"
        umount $SNAP_MOUNTDIR/mysql
        Log "Removing the snapshot: $LVM_SNAP"
        /sbin/lvremove -f $LVM_SNAP

    fi
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME ] || [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME ] && Log "Removing backuped position and config files"
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME ] && rm -vf $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME ] && rm -vf $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME
}


function do_main_checks() {

    # Check the mysql datadir filesystem type
    MYSQL_FS_TYPE=$(/sbin/blkid -s TYPE -o value $LVM_MYSQL)
    [ -z "$MYSQL_FS_TYPE" ] && LogError "Can't determine the filesystem type of the mysql datadir volume"

    [ -z "$MYSQL_LVM_MOUNTDIR" ] && LogError "The root mysql lvm volume is not mounted: $LVM_MYSQL"
    [ -z "$ARG_DEST" ] || [ ! -d $ARG_DEST ] && LogError "The destination directory does not exist: $ARG_DEST"
}


function do_preprocessing_checks() {
    Log "=== Starting preprocessing checks ==="
    Log "Pool: ${POOL_ID}"
    Log "Platform: ${PLATFORM}"
    
    MY_TYPE='-'
    mysql -e 'show slave status\G'|grep -q 'Slave_IO_Running: Yes' && MY_TYPE='SLAVE'
    mysql -BNe "show variables like 'read_only'"|awk '{print $2}'|grep -q 'OFF' && MY_TYPE='MASTER'
    echo "[Pool:${POOL_ID}] I'am a: $MY_TYPE"
    
    if [ $ARG_SHARED -eq 1 ]; then
        # Shared mode
        echo "[Pool:${POOL_ID}] Shared mode is Enabled"
        sleep_time=$(($RANDOM%RANDOM_WAIT_TIME))
        Log "Sleeping random time: $sleep_time sec"
        sleep $sleep_time
    
        echo "[Pool:${POOL_ID}] Synchro file used in shared mode: $SHARED_LOCK_FILE"
        find $ARG_DEST -maxdepth 1 -type f -name  ${SHARED_LOCK_FILENAME} -mmin +$(((${ARG_SHARED_WAIT}/60)+1)) -exec rm -vf {} \;
    
    	# Slave election
        echo "$(hostname -f);$MY_TYPE" >>$SHARED_LOCK_FILE
        echo "[Pool:${POOL_ID}] Waiting for slave synchronisation in shared mode... (sleeping $ARG_SHARED_WAIT sec)"
        sleep $ARG_SHARED_WAIT
    
        nr_available_slaves=$(grep ';SLAVE$' $SHARED_LOCK_FILE|sort -u|wc -l|awk '{print $1}')
        first_available_slave=$(grep ';SLAVE$' $SHARED_LOCK_FILE|head -1|cut -d';' -f1)
    
        echo "[Pool:${POOL_ID}] Number of available slaves: $nr_available_slaves"
        echo "[Pool:${POOL_ID}] First available slave: $first_available_slave"
    
        if [ $nr_available_slaves -ge 1 ] && [ -n "$first_available_slave" ]; then
            [ "$MY_TYPE" == "MASTER" ] && LogError "[Pool:${POOL_ID}] Iam a master and some slaves are available for the backup. ABORT."
            [ "$first_available_slave" != "$(hostname -f)" ] && LogError "[Pool:${POOL_ID}] I'am not the elected slave. ABORT."
        else
            echo "No available slaves"
            [ "$MY_TYPE" == "MASTER" ] && [ $ARG_FORCE_MASTER -eq 0 ] && LogError "[Pool:${POOL_ID}] I'am a MASTER but i'am not configured to perform a backup. ABORT."
        fi
    else
    # We backup only a slave
        [ $ARG_STANDALONE -eq 0 ] && [ $MY_TYPE != "SLAVE" ] && LogError "[Pool:${POOL_ID}] Oops: I'am not a slave or replication is not running. ABORT."
    fi

}

function myexit() {
    Log "Exiting ..."
    [ -f $MYSQL_POS_FILE ] && rm -f $MYSQL_POS_FILE
    release_snap
    [ -d $SNAP_MOUNTDIR/mysql ] && rmdir $SNAP_MOUNTDIR/mysql
    [ -d $SNAP_MOUNTDIR ] && rmdir $SNAP_MOUNTDIR
    [ -f $MYSQL_POS_FILE ] && rm -f $MYSQL_POS_FILE
    [ $REMOVE_LOCK_FILE -eq 1 ] && rm -vf $SHARED_LOCK_FILE

}



############
### MAIN ###
############

# ARGS
ARG_STANDALONE=0

ts_start=$(date +%s)

[ -n "$BIN_PV" ] || LogError "Can't find PV (pipe viewer)"

# Get Args

ARG_DEST=
ARG_STANDALONE=0
ARG_SHARED=0
ARG_FORCE_MASTER=0
REMOVE_LOCK_FILE=0
ARG_BANDWITH_WRITE_LIMIT_M=

while getopts g:l:s:d:L:r:SXW:Fh option; do
    case "$option" in
        g) ARG_LVM_VG=$OPTARG ;;
        l) ARG_LVM_SRC=$OPTARG ;;
        s) ARG_LVM_SNAP_SIZE=$OPTARG ;;
        d) ARG_DEST=$OPTARG ;;
        L) ARG_BANDWITH_WRITE_LIMIT_M=$OPTARG ;;
        r) ARG_RETENTION_DAYS=$OPTARG ;;
        S) ARG_STANDALONE=1 ;;
        X) ARG_SHARED=1 ;;
        W) ARG_SHARED_WAIT=$OPTARG ;;
        F) ARG_FORCE_MASTER=1 ;;
        h) printSyntax; exit ;;
    esac
done

ARG_LVM_SRC=${ARG_LVM_SRC}
SNAP_SIZE=${ARG_LVM_SNAP_SIZE:-$SNAP_SIZE_DEFAULT}
LVM_MYSQL=/dev/mapper/$ARG_LVM_VG-$ARG_LVM_SRC
LVM_SNAP=/dev/mapper/$ARG_LVM_VG-$LVM_SNAP_NAME
ARG_RETENTION_DAYS=${ARG_RETENTION_DAYS:-$RETENTION_DAYS_DEFAULT}
ARG_SHARED_WAIT=${ARG_SHARED_WAIT:-$SHARED_WAIT_DEFAULT}

# Check Args
check_args


MYSQL_LVM_MOUNTDIR=$(get_device_mountdir $LVM_MYSQL)
hostname_digits=($( hostname -s|sed 's/my//;s/\([0-9]\)/\1 /g'))
# PLATFORM = POOL_ID + HOSTNAME_KEY
# The pool id is fixed the FQDN (the second digit of the short name beginning by the end)
POOL_ID=${hostname_digits[-2]}
MEMBER_ID=${hostname_digits[-1]}
PLATFORM=$(hostname -f|sed 's/[0-9]//g;s/\./-/g'|cut -d'-' -f1-4).pool${POOL_ID}
SHARED_LOCK_FILENAME=${PLATFORM}.lock
SHARED_LOCK_FILE=$ARG_DEST/${SHARED_LOCK_FILENAME}

do_preprocessing_checks
Log "=== Starting the DUMP of all databases ==="
do_main_checks

Log "Creating directory: ${ARG_DEST}/${PLATFORM}"
mkdir -p ${ARG_DEST}/${PLATFORM} || LogError "Can't create the directory: $ARG_DEST/$PLATFORM"
REMOVE_LOCK_FILE=1

BACKUP_FILE=${ARG_DEST}/${PLATFORM}/${BACKUP_FILE_PREFIX}-Pool${POOL_ID}-${HOSTNAME}_${DATE}.tgz
LAST_BACKUP_FILE=${ARG_DEST}/LAST_FULL_BACKUP_DATABASE

do_before_snap
create_snap
mount_snap || LogError "Can't mount the snapshot $LVM_SNAP_NAME on $SNAP_MOUNTDIR"

trap myexit EXIT
do_local_archive
release_snap

# Write into the last backup file (could be useful for monitoring)
Log "Update the last backup file: $LAST_BACKUP_FILE"
date > $LAST_BACKUP_FILE
echo $BACKUP_FILE >> $LAST_BACKUP_FILE

Log "All is done"
[ $ARG_SHARED -eq 1 ] && [ -f $SHARED_LOCK_FILE ] && rm -f $SHARED_LOCK_FILE


