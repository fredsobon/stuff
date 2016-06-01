#!/bin/bash

# vim: set sw=4 et ts=4

# Author: d.larquey@pixmania-group.com
# Last modified: Thu, Mar 15 11:44:22

# BE CAREFUL:
# This script is executed on ALL mysql database servers
# Only servers explicitly entered in the variable $DO_BACKUP_ON_HOST will be selected to perform a backup

# Summary:
# This script performs a full backup of the mysql basedir (all databases) by creating a gzipped tar archive
# A snapshot of the mysql basedir is made and used as the source of the archive
# The backup archive is stored on $BACKUP_DESTDIR/${HOSTNAME} (it could be a remote backup volume)
# The destination directory must be a volume

# Output:
# The full backup archive is stored on:
# - $BACKUP_DESTDIR/${HOSTNAME}
# A file is updated only if the backup was succesfull
# - $LAST_SUCCESFULL_BACKUP_FILE : ${BACKUP_DESTDIR}/LAST_FULL_BACKUP_DATABASE


DATE=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname -f)

# List of all slaves authorized to perform a backup
DO_BACKUP_ON_HOST=(my31.db.pix.prod.vit.e-merchant.net)

# Source & Destination of the backup
# Default INPUTS
VG=mvg
LVM_MYSQL_NAME=mysql

# OUTPUT
BACKUP_DESTDIR=/srv/mysqldump01 # mysqldump01
BACKUP_RETENTION_DAYS=5	# Number of backups (in days) to keep for retention

# LVM snapshot
SNAP_SIZE=10
LVM_SNAP_NAME=mysqlsnapshot01
SNAP_MOUNTDIR=/tmp/mysqlsnapshot01

# Mysql
TEMP_MYSQL_POS_FILE=/tmp/backup-mysql_${DATE}_mysql.pos
MYSQL_CONFIG_FILE=/etc/mysql/my.cnf

# Backup
BACKUP_FILE_PREFIX="mysql-fullbackup-$HOSTNAME"
GZIP_OPTS="--verbose --fast"

# MISC



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

function get_device_type {
        local mnt="$1"
        awk "(\$2==\"$mnt\") {print \$3}" /proc/mounts 2>/dev/null
}

function create_snap() {
    if /sbin/lvs $LVM_SNAP >/dev/null 2>&1; then
        mnt_snap=$(get_device_mountdir $LVM_SNAP)
        [ -n "$mnt_snap" ] && LogError "The snapshot $LVM_SNAP_NAME is already mounted on $mnt_snap"
        LogError "The snapshot $LVM_SNAP_NAME already exists!"
    fi

    # Create the snapshot
    Log "Taking the LVM snapshot by locking tables: $LVM_SNAP_NAME"
    mysql -e "$SNAP_CMD" >$TEMP_MYSQL_POS_FILE
    return $?
}

function mount_snap() {
    /sbin/lvs $LVM_SNAP >/dev/null 2>&1 || LogError "Missing snapshot!"
    local CMD="mount -t $MYSQL_FS_TYPE $LVM_SNAP $SNAP_MOUNTDIR/mysql"
    if [ -d  $SNAP_MOUNTDIR ]; then
        echo "Removing the snapshot mountpoint before mounting: $SNAP_MOUNTDIR"
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

function before_doing_dump() {
    Log "Copying position and config file"
    cp -a $MYSQL_CONFIG_FILE $SNAP_MOUNTDIR/backup-mysql_${DATE}_my.cnf
    cp -a $TEMP_MYSQL_POS_FILE $SNAP_MOUNTDIR/
}

function do_local_archive() {
    Log "Creating the archive: $BACKUP_FILE ..."
    CMD="time tar -C $SNAP_MOUNTDIR -cvf - . | gzip --stdout $GZIP_OPTS"
    Log "Running: $CMD"
    eval $CMD >${BACKUP_FILE}.INCOMPLETE
    ret=$?
    if [ $ret -eq 0 ]; then
            Log "The archive was succesfully created: ${BACKUP_FILE}"
            mv ${BACKUP_FILE}.INCOMPLETE ${BACKUP_FILE}
            Log "Purging old local archives"
	    local retention_minutes=$(($BACKUP_RETENTION_DAYS*1440 - (($(date +%s)-$ts_start)/60)))
	    find $REMOTE_BACKUP_MOUNTDIR/$REMOTE_BACKUP_DIR/ -type f -mmin +$retention_minutes -name ${BACKUP_FILE_PREFIX}\*.tgz -exec rm -vf {} \;
    else
            backup_file=$(ls -1 ${BACKUP_FILE}*)
            if [ -n "$backup_file" ] && [ -f $backup_file ]; then
                ls -l $backup_file
                Log "Removing the incomplete archive: $backup_file"
                rm -f $backup_file
            fi
            LogError "The archive was not succesfully created. Backup has failed. Please check."
    fi
    rm -vf ${BACKUP_DESTDIR}/${HOSTNAME}/${BACKUP_FILE_PREFIX}_*.INCOMPLETE
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
}

function do_main_checks() {
    # Check the mysql datadir filesystem type
    MYSQL_FS_TYPE=$(/sbin/blkid -s TYPE -o value $LVM_MYSQL)
    [ -z "$MYSQL_FS_TYPE" ] && LogError "Can't determine the filesystem type of the mysql datadir volume"
    
    # Check if the destination directory is already mounted
    local dev=`get_mounted_device $BACKUP_DESTDIR`
    [ -n "$dev" ] || LogError "The destination directory must be a volume: $BACKUP_DESTDIR"

    if [ $CHECK_REMOTE_DIR -eq 1 ]; then
        local type=`get_device_type $BACKUP_DESTDIR`
        [ -z "$type" ] || [ "$type" != "nfs" ] && LogError "The backup destination directory is not a remote volume"
    fi

    if [ ! -d ${BACKUP_DESTDIR}/${HOSTNAME} ]; then
	    Log "Creating the backup destination directory: ${BACKUP_DESTDIR}/${HOSTNAME}"
    	mkdir -p ${BACKUP_DESTDIR}/${HOSTNAME} || LogError "Can't create the destination backup volume: ${BACKUP_DESTDIR}/${HOSTNAME}"
	fi
}


function myexit() {
    Log "Exiting ..."
    [ -f $TEMP_MYSQL_POS_FILE ] && rm -f $TEMP_MYSQL_POS_FILE
    release_snap
    [ -d $SNAP_MOUNTDIR ] && rm -rf $SNAP_MOUNTDIR
    [ -f $TEMP_MYSQL_POS_FILE ] && rm -f $TEMP_MYSQL_POS_FILE
}


function check_slave() {
	local check_host=0
	for host in $(seq 0 $((${#DO_BACKUP_ON_HOST[@]}-1))); do
		[ "${HOSTNAME}" == "${DO_BACKUP_ON_HOST[$i]}" ] && check_host=1
	done
	[ $check_host -ne 1 ] && LogError "I'am not a slave configured to perform a mysql full backup"
	pgrep -f /usr/sbin/mysqld >/dev/null || LogError "mysqld is not running. Abort"
	mysql -sBN -e "show status like 'Slave_running'"|awk '{print $2}'|grep -q ON || LogError "Mysql slave thread is not running"
}

function printSyntax() {
cat <<EOS
$(basename $0) - Script to backup all mysql databases on this host"
This script must be launched by cron and it performs a consistent full backup of all mysql databases hosted on this host by freezing the filesystem: LVM_SOURCE_NAME
The destination backup directory must be a volume

$(basename $0) [-g VOLUME_GROUP] [-l LVM_SOURCE_NAME] [-s SNAPSHOT_SIZE] [-d DESTINATION_DIRECTORY] [-r DAYS_OF_RETENTION] [-R]

Default values are:
- VG=mvg
- LVM_SOURCE_NAME=mysql
- SNAPSHOT_SIZE=20g
- DESTINATION_DIRECTORY= /srv/mysqldump01/HOSTNAME
- DAYS_OF_RETENTION=5

    -h      Print this help
    -R      Check if the backup destination directory is a remote volume (NFS)

EOS
}


############
### MAIN ###
############
ts_start=$(date +%s)

CHECK_REMOTE_DIR=0
while getopts g:l:s:d:r:Rh option; do
    case "$option" in
        g) VG=$OPTARG ;;
        l) LVM_MYSQL_NAME=$OPTARG ;;
        s) SNAP_SIZE=$OPTARG ;;
        d) BACKUP_DESTDIR=$OPTARG ;;
        r) BACKUP_RETENTION_DAYS=$OPTARG ;;
        R) CHECK_REMOTE_DIR=1 ;;
        h) printSyntax; exit ;;
    esac
done

LVM_MYSQL=/dev/mapper/$VG-$LVM_MYSQL_NAME
LVM_SNAP=/dev/mapper/$VG-$LVM_SNAP_NAME
LAST_SUCCESFULL_BACKUP_FILE=${BACKUP_DESTDIR}/LAST_FULL_BACKUP_DATABASE
BACKUP_FILE=${BACKUP_DESTDIR}/${HOSTNAME}/${BACKUP_FILE_PREFIX}_${DATE}.tgz
SNAP_CMD="flush tables with read lock; system sync; system /sbin/lvcreate --size ${SNAP_SIZE}g --snapshot /dev/$VG/$LVM_MYSQL_NAME --name $LVM_SNAP_NAME; show slave status\G; unlock tables;"
[ -e /dev/mapper/$VG-$LVM_MYSQL_NAME ] || LogError "Can't find LVM volume $LVM_MYSQL_NAME on the volume group $VG"

check_slave

Log "=== Starting the DUMP of all databases on the server $HOSTNAME ==="
do_main_checks

create_snap
mount_snap || LogError "Can't mount the snapshot $LVM_SNAP_NAME on $SNAP_MOUNTDIR"

trap myexit EXIT
before_doing_dump
do_local_archive
release_snap

# Write into the last backup file (could be useful for monitoring)
Log "Update the last backup file: $LAST_SUCCESFULL_BACKUP_FILE"
date > $LAST_SUCCESFULL_BACKUP_FILE
echo $BACKUP_FILE >>$LAST_SUCCESFULL_BACKUP_FILE

Log "All is done"

