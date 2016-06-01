#!/bin/bash

# Author: David Larquey, <d.larquey@pixmania-group.com>
# Last modified: Fri Aug  8 16:58:20 CEST 2014, œdlarquey


# --- SVN  properties ---
# $HeadURL: http://svn.e-merchant.net/svn/norel-dba/dbawork_mysql/shell/cron/mysql_snap_full_backup.sh $ $Revision: 762 $
# $Author: d.larquey $ $Date: 2015-03-17 12:50:38 +0100 (mar. 17 mars 2015) $

# Summary:
# This script uses a LVM snapshot to perform a full backup of all databases. It creates a gzipped tar archive as result
# Only a slave could be backuped
# A snapshot of the mysql datadir is made and mounted as the source of the archive
# The archive is made on a local volume (stored into the destination volume $LVM_BACKUP_NAME) and then exported to a remote backup volume $REMOTE_BACKUP_MOUNTDIR if DO_REMOTE_BACKUP is true.

# Input:
# All arguments are optional

# Output:
# The full backup archive is stored on:
# - LVM local volume $LVM_BACKUP mounted on $LVM_BACKUP_MOUNTDIR
# - Optionally: Remote NFS volume: $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR

# Changelogs
# 08/08/2014    dlarquey   Add the pv command to limit IO bandwith on the local backup volume


export PATH=$PATH:/usr/bin

DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=${HOSTNAME:=$(hostname -f)}

# LVM
VG=mvg
LVM_MYSQL_NAME=mysql

LVM_BACKUP_NAME=backup
LVM_BACKUP_MOUNTDIR=

# LVM snap
SNAP_SIZE=30g
LVM_SNAP_NAME=mysqlsnapshot01
SNAP_MOUNTDIR=/tmp/mysqlsnapshot01

# Mysql
MYSQL_POS_FILENAME=backup-mysql_${DATE}.pos
MYSQL_POS_FILE=/tmp/$MYSQL_POS_FILENAME
MYSQL_CONFIG_FILE=/etc/mysql/my.cnf
MYSQL_CONFIG_FILE_COPY_FILENAME=backup-mysql_${DATE}.cnf
ARG_STANDALONE=0

# Backup
BACKUP_FILE_PREFIX="MYSQL_BACKUP_FULL-$HOSTNAME"
LOCAL_BACKUP_RETENTION_DAYS=5
LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M=2

# Remote backups
DO_REMOTE_BACKUP=0
REMOTE_BACKUP_MOUNTDIR=/srv/mysqldump01
REMOTE_BACKUP_DIR=$HOSTNAME
REMOTE_BACKUP_RETENTION_DAYS=7
REMOTE_RSYNC_OPTS='-av --bwlimit=35000' # limit I/O bandwidth (KB/s)

# MISC
BIN_PV=$(which pv 2>/dev/null)


#################
### Functions ###
#################

function printSyntax() {
cat <<EOS
$(basename $0) - Perform a MySQL full backup database using LVM

Syntax:
$(basename $0) [-g VG] [-l LV_Source] [-d LV_Destination] [-s SnapSize] [-r Retention] [[-x] [-D Remote_Destination] [-R Remote_Retention]] [-h] [-S]

Prerequisites

All MySQL datas (datas + binlogs + relaylogs)  must be on a same LVM volume

Options
    -g Volume group for both the source volume and the backup destination. Default is '$VG'
    -l Logical volume name for the local SOURCE (MySQL datadir to backup). Default is '$LVM_MYSQL_NAME'
    -d Logical volume name for the local DESTINATION of the backup. Default is '$LVM_BACKUP_NAME'
    -s Snapshot size. Default is ${SNAP_SIZE}
    -L Bandwith limit for the local backup. default is ${LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M}MB/sec
    -r Retention of the local LVM backups (in days). Default is $LOCAL_BACKUP_RETENTION_DAYS
    -x Do a local backup then copy it to a remote destination. Disabled by default
        -D if '-x' option is enabled: Remote destination volume (The directory of a mounted NFS share). Default is '${REMOTE_BACKUP_MOUNTDIR}'
        -R if '-x' option is enabled: Remote retention of the backups (in days). Default is $REMOTE_BACKUP_RETENTION_DAYS
    -S standalone: bypass the master/slave status check

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
    /sbin/vgs --noheadings -o vg_name $VG &>/dev/null || LogError "Wrong Volume Groupe: $VG"
    check_lvm $LVM_MYSQL
    check_lvm $LVM_BACKUP
    echo $SNAP_SIZE|egrep -qi '^[0-9]+(m|g)$' || LogError "Wrong snapshot size: $SNAP_SIZE"
    is_integer $LOCAL_BACKUP_RETENTION_DAYS || LogError "Wrong local retention: $LOCAL_BACKUP_RETENTION_DAYS"
    echo $DO_REMOTE_BACKUP|egrep -q '^0|1$' || LogError "Wrong value for enabling/disabling remote backup"

    if [ $DO_REMOTE_BACKUP -eq 1 ]; then
        [ -d $REMOTE_BACKUP_MOUNTDIR ] || LogError "The directory does not exist: $REMOTE_BACKUP_MOUNTDIR"
        is_integer $REMOTE_BACKUP_RETENTION_DAYS || LogError "Wrong remote retention: $REMOTE_BACKUP_RETENTION_DAYS"
    fi
}

function create_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        mnt_snap=$(get_device_mountdir $LVM_SNAP)
        [ -n "$mnt_snap" ] && LogError "The snapshot $LVM_SNAP_NAME is already mounted on $mnt_snap"
        LogError "The snapshot $LVM_SNAP_NAME already exists!"
    fi

    # Create the snapshot
    SNAP_CMD="flush tables with read lock; system sync; system /sbin/lvcreate --size $SNAP_SIZE --snapshot /dev/$VG/$LVM_MYSQL_NAME --name $LVM_SNAP_NAME; show slave status\G; unlock tables;"
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
    CMD="time tar -cvf - -C $(dirname $MYSQL_POS_FILE) $MYSQL_POS_FILENAME -C $SNAP_MOUNTDIR . |gzip --stdout --verbose --fast | ${BIN_PV} -L ${LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M}m"
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
        /sbin/lvremove -f $LVM_SNAP

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

    # Check the mysql datadir filesystem type
    MYSQL_FS_TYPE=$(/sbin/blkid -s TYPE -o value $LVM_MYSQL)
    [ -z "$MYSQL_FS_TYPE" ] && LogError "Can't determine the filesystem type of the mysql datadir volume"

    # test MYSQL_LVM_MOUNTDIR & LVM_BACKUP_MOUNTDIR
    [ -z "$MYSQL_LVM_MOUNTDIR" ] && LogError "The root mysql lvm volume is not mounted: $LVM_MYSQL"
    [ -z "$LVM_BACKUP_MOUNTDIR" ] && LogError "The local backup volume is not mounted: $LVM_BACKUP"
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

[ -n "$BIN_PV" ] || LogError "Can't find PV (piper viewer)"

# Get Args
while getopts g:l:d:s:L:r:xD:R:Sh option; do
    case "$option" in
        g) ARG_LVM_VG=$OPTARG;;
        l) ARG_LVM_SRC=$OPTARG;;
        d) ARG_LVM_DEST=$OPTARG;;
        L) ARG_LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M=$OPTARG ;;
        s) ARG_LVM_SNAP_SIZE=$OPTARG;;
        r) ARG_LVM_LOCAL_RDAYS=$OPTARG;;
        x) ARG_LVM_DO_REMOTE_BACKUP=1;;
        D) ARG_REMOTE_DEST=$OPTARG;;
        R) ARG_REMOTE_RDAYS=$OPTARG;;
        S) ARG_STANDALONE=1;;
        h) printSyntax; exit ;;
    esac
done

VG=${ARG_LVM_VG:-$VG}
LVM_MYSQL_NAME=${ARG_LVM_SRC:-$LVM_MYSQL_NAME}
LVM_BACKUP_NAME=${ARG_LVM_DEST:-$LVM_BACKUP_NAME}
SNAP_SIZE=${ARG_LVM_SNAP_SIZE:-$SNAP_SIZE}
LOCAL_BACKUP_RETENTION_DAYS=${ARG_LVM_LOCAL_RDAYS:-$LOCAL_BACKUP_RETENTION_DAYS}
DO_REMOTE_BACKUP=${ARG_LVM_DO_REMOTE_BACKUP:-$DO_REMOTE_BACKUP}
REMOTE_BACKUP_MOUNTDIR=${ARG_REMOTE_DEST:-$REMOTE_BACKUP_MOUNTDIR}
REMOTE_BACKUP_RETENTION_DAYS=${ARG_REMOTE_RDAYS:-$REMOTE_BACKUP_RETENTION_DAYS}
LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M=${ARG_LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M:-$LOCAL_BACKUP_BANDWITH_WRITE_LIMIT_M}

LVM_MYSQL=/dev/mapper/$VG-$LVM_MYSQL_NAME
LVM_BACKUP=/dev/mapper/$VG-$LVM_BACKUP_NAME
LVM_SNAP=/dev/mapper/$VG-$LVM_SNAP_NAME

# Check Args
check_args


Log "=== Starting the DUMP of all databases ==="

MYSQL_LVM_MOUNTDIR=$(get_device_mountdir $LVM_MYSQL)
LVM_BACKUP_MOUNTDIR=$(get_device_mountdir $LVM_BACKUP)

# We backup only a slave
if [ $ARG_STANDALONE -eq 0 ]; then
    mysql -e 'show slave status\G'|grep -q 'Slave_IO_Running: Yes' || LogError "Oops: I'am not a slave or replication is not running. ABORT."
fi

do_main_checks
BACKUP_FILE=$LVM_BACKUP_MOUNTDIR/${BACKUP_FILE_PREFIX}_${DATE}.tgz
LAST_BACKUP_FILE=$LVM_BACKUP_MOUNTDIR/LAST_FULL_BACKUP_DATABASE

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

