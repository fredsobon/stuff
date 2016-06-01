#!/bin/bash

# Author: d.larquey@pixmania-group.com
# Last modified: Thu, Jan 17 10:11:22

# Summary:
# This script uses a LVM snapshot to perform a full backup of all databases. It creates a gzipped tar archive as result
# Only a slave could be backuped
# A snapshot of the mysql datadir is made and mounted as the source of the archive
# The archive is made on a local volume ($LVM_BACKUP_MOUNTDIR) and then exported to a remote backup volume $REMOTE_BACKUP_MOUNTDIR if DO_REMOTE_BACKUP is true.

# Input:
# Nothing

# Output:
# The full backup archive is stored on:
# - LVM local volume: $LVM_BACKUP_MOUNTDIR
# - Remote NFS volume: $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR



DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=${HOSTNAME:=$(hostname -f)}

# LVM
VG=mvg
LVM_MYSQL_NAME=mysql
LVM_MYSQL=/dev/mapper/$VG-$LVM_MYSQL_NAME

LVM_BACKUP_NAME=mysql_backup
LVM_BACKUP=/dev/mapper/$VG-$LVM_BACKUP_NAME
LVM_BACKUP_MOUNTDIR=/srv/backup

# LVM snap
SNAP_SIZE=2g
LVM_SNAP_NAME=mysqlsnapshot01
LVM_SNAP=/dev/mapper/$VG-$LVM_SNAP_NAME
SNAP_MOUNTDIR=/tmp/mysqlsnapshot01

# Mysql
MYSQL_POS_FILENAME=backup-mysql_${DATE}.pos
MYSQL_POS_FILE=/tmp/$MYSQL_POS_FILENAME
MYSQL_CONFIG_FILE=/etc/mysql/my.cnf
MYSQL_CONFIG_FILE_COPY_FILENAME=backup-mysql_${DATE}.cnf

# Backup
BACKUP_FILE_PREFIX="MYSQL_BACKUP_FULL-$HOSTNAME"
BACKUP_FILE=$LVM_BACKUP_MOUNTDIR/${BACKUP_FILE_PREFIX}_${DATE}.tgz
LOCAL_BACKUP_RETENTION_DAYS=5

# Remote backups
DO_REMOTE_BACKUP=0
REMOTE_BACKUP_MOUNTDIR=/srv/mysqldump01
REMOTE_BACKUP_DIR=$HOSTNAME
REMOTE_BACKUP_RETENTION_DAYS=7
REMOTE_RSYNC_OPTS='-av --bwlimit=35000' # limit I/O bandwidth (KB/s)

# MISC
SNAP_CMD="flush tables with read lock; system sync; system /sbin/lvcreate --size $SNAP_SIZE --snapshot /dev/$VG/$LVM_MYSQL_NAME --name $LVM_SNAP_NAME; show slave status\G; unlock tables;"

LAST_BACKUP_FILE=$LVM_BACKUP_MOUNTDIR/LAST_FULL_BACKUP_DATABASE



#################
### Functions ###
#################

function LogError() {
        echo -e "[$(date)] $@" >&2
        exit 1
}

function Log() {
        echo -e "[$(date)] $@"
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
    /sbin/lvs --noheadings|awk '{print $1}'|grep -q "^$1$"
}

function create_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        mnt_snap=$(get_device_mountdir $LVM_SNAP)
        [ -n "$mnt_snap" ] && LogError "The snapshot $LVM_SNAP_NAME is already mounted on $mnt_snap"
        LogError "The snapshot $LVM_SNAP_NAME already exists!"
    fi

    # Create the snapshot
    Log "Taking the LVM snapshot by locking tables: $LVM_SNAP_NAME"
    mysql -e "$SNAP_CMD" >$MYSQL_POS_FILE
    return $?
}

function mount_snap() {
    /sbin/lvs $LVM_SNAP >/dev/null 2>&1 || LogError "Missing snapshot!"
    local CMD="mount -t $MYSQL_FS_TYPE -o ro $LVM_SNAP $SNAP_MOUNTDIR/mysql"
    if [ -d  $SNAP_MOUNTDIR ]; then
        echo "Purging the snapshot mountpoint before mounting: $SNAP_MOUNTDIR"
        rm -rf  $SNAP_MOUNTDIR
    fi
    mkdir -p $SNAP_MOUNTDIR/mysql
    local mnt=$(get_mounted_device $SNAP_MOUNTDIR)
    [ -n "$mnt" ] && LogError "A volume is already mounted on the snapshot mountdir: $SNAP_MOUNTDIR"
    Log "Mounting the snapshot on $SNAP_MOUNTDIR/mysql"
    Log "Runnnig: $CMD"
    $CMD
    return $?
}

function do_before_snap() {
    Log "Copying position and config files"
    cp -a $MYSQL_CONFIG_FILE $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME
}

function do_local_archive() {
    Log "Creating the archive: $BACKUP_FILE ..."
    CMD="time tar -cvf - -C $(dirname $MYSQL_POS_FILE) $MYSQL_POS_FILENAME -C $SNAP_MOUNTDIR . |gzip --stdout --verbose --fast"
    Log "Running: $CMD"
    eval $CMD >${BACKUP_FILE}.INCOMPLETE
    ret=$?
    if [ $ret -eq 0 ]; then
        Log "The archive was succesfully created: ${BACKUP_FILE}"
        mv ${BACKUP_FILE}.INCOMPLETE ${BACKUP_FILE}
        Log "Purging old local archives (Retention: $LOCAL_BACKUP_RETENTION_DAYS days)"

        local retention_minutes=$(($LOCAL_BACKUP_RETENTION_DAYS*1440 - (($(date +%s)-$ts_start)/60)))
        find $LVM_BACKUP_MOUNTDIR -type f -mmin +$retention_minutes -name ${BACKUP_FILE_PREFIX}\*.tgz -exec rm -vf {} \;
    else
            if [ -f ${BACKUP_FILE}.INCOMPLETE ]; then
                ls -l $backup_file
                Log "Removing the incomplete archive: ${BACKUP_FILE}.INCOMPLETE"
                rm -f ${BACKUP_FILE}.INCOMPLETE
            fi
            LogError "The archive was not succesfully created. Backup has failed. Please check."
    fi
    rm -vf $LVM_BACKUP_MOUNTDIR/${BACKUP_FILE_PREFIX}_*.INCOMPLETE  
}

function release_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        Log "Snap usage:"
        /sbin/lvs $LVM_SNAP
        Log "Unmounting the snapshot: $LVM_SNAP"
        umount $SNAP_MOUNTDIR/mysql
        Log "Removing the snapshot: $LVM_SNAP"
        lvremove -f $LVM_SNAP

    fi
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME ] || [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME ] && Log "Removing backuped position and config files"
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME ] && rm -vf $MYSQL_LVM_MOUNTDIR/$MYSQL_CONFIG_FILE_COPY_FILENAME
    [ -f $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME ] && rm -vf $MYSQL_LVM_MOUNTDIR/$MYSQL_POS_FILENAME
}

function transfer_archive_to_remote_host() {
    [ $DO_REMOTE_BACKUP -ne 1 ] && return
    [ -f $BACKUP_FILE ] || return
    [ -d $REMOTE_BACKUP_MOUNTDIR ] || LogError "The remote backup directory is missing: $REMOTE_BACKUP_MOUNTDIR"

    Log "Sync the archive to the remote volume: $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR"
    mkdir -p $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR
    rsync $REMOTE_RSYNC_OPTS $BACKUP_FILE $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR/ &
    local job=$!
    echo -n "Waiting for the job to complete: <$job> "
    while [ -d /proc/$job ]; do
            echo -n 3>/proc/sys/vm/drop_caches
            echo -n '.'
            sleep 10
    done
    Log "The transfer of the archive on the remote volume was done"
    Log "Purging old archives on the remote volume (older than $REMOTE_BACKUP_RETENTION_DAYS days)"
    local retention_minutes=$(($REMOTE_BACKUP_RETENTION_DAYS*1440 - (($(date +%s)-$ts_start)/60)))
    find $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR/ -type f -mmin +$retention_minutes -name ${BACKUP_FILE_PREFIX}\*.tgz -exec rm -vf {} \;
}

function do_main_checks() {

    /sbin/lvs $LVM_MYSQL >/dev/null 2>&1 || LogError "The lvm volume does not exist: $LVM_MYSQL"
    /sbin/lvs $LVM_BACKUP >/dev/null 2>&1 || LogError "The lvm volume does not exist: $LVM_BACKUP"

    # Check the mysql datadir filesystem type
    MYSQL_FS_TYPE=$(blkid -s TYPE -o value $LVM_MYSQL)
    [ -z "$MYSQL_FS_TYPE" ] && LogError "Can't determine the filesystem type of the mysql datadir volume"

    # test MYSQL_LVM_MOUNTDIR
    [ -z "$MYSQL_LVM_MOUNTDIR" ] && LogError "The root mysql lvm volume is not mounted: $LVM_MYSQL"
    
    # Check if the local backup volume is mounted
    mnt=$(get_device_mountdir $LVM_BACKUP)
    [ -z "$mnt" ] && LogError "The local backup volume is not mounted: $LVM_BACKUP"
    [ "$mnt" != "$LVM_BACKUP_MOUNTDIR" ] && LogError "The local backup volume is not mounted as expected: <$mnt> instead of $LVM_BACKUP_MOUNTDIR"
}


function myexit() {
    Log "Exiting ..."
    [ -f $MYSQL_POS_FILE ] && rm -f $MYSQL_POS_FILE
    release_snap
    [ -d $SNAP_MOUNTDIR ] && rm -rf $SNAP_MOUNTDIR
    [ -f $MYSQL_POS_FILE ] && rm -f $MYSQL_POS_FILE
}





############
### MAIN ###
############
ts_start=$(date +%s)

Log "=== Starting the DUMP of all databases ==="

# We backup only a slave
mysql -e 'show slave status\G'|grep -q 'Slave_IO_Running: Yes' || LogError "Oops: I'am not a slave or replication is not running. ABORT."

MYSQL_LVM_MOUNTDIR=$(get_device_mountdir $LVM_MYSQL)
do_main_checks

do_before_snap
create_snap
mount_snap || LogError "Can't mount the snapshot $LVM_SNAP_NAME on $SNAP_MOUNTDIR"

trap myexit EXIT
do_local_archive
release_snap

transfer_archive_to_remote_host

# Write into the last backup file (could be useful for monitoring)
Log "Update the last backup file: $LAST_BACKUP_FILE"
date > $LAST_BACKUP_FILE
echo $BACKUP_FILE >> $LAST_BACKUP_FILE

Log "All is done"

