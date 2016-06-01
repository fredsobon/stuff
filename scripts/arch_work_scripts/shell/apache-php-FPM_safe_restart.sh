#!/bin/bash

# vim: set ft=sh sw=4 et ts=4

# Script for restarting Apache/PHP FPM safely on a front PROD real web server
# Author: dlarquey <d.larquey@pixmania-group.com> , Fri Jun 15 12:48:39

# Details : 
# this script performs:
# - Forcing the healthcheck tests from all load balancers to fail (by modifying string into healthcheck files)
# - stop apache and then php FPM. EXIT with error if timeout
# - restart servcies. EXIT with error if it fails
# - test if the service answers properly


APACHECTL=/usr/sbin/apache2ctl
APACHE2=/usr/sbin/apache2
PHP5FPM=php5-fpm
INIT_PHP=/etc/init.d/php5-fpm
INIT_APACHE2=/etc/init.d/apache2

LOCK_FILE=/var/lock/$(basename $0|sed s/.sh$//).lock
HEALTHCHECK_BASEDIR=/home
HEALTHCHECK_FILE_SUFFIX=healthcheck/check.php
MAX_RETRIES=120 # seconds

HOSTNAME=$(hostname -f)
HEALTHCHECK_FILES=



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
}

function change_loadbalancer_state {
	declare -i state=0
        for file in $HEALTHCHECK_FILES; do
                log "Forcing '$2' state for LB healthcheck file: $file"
                sed -i s/\'$1\'/\'$2\'/ $file
		state=$((state|$?))
                sed -i s/\"$1\"/\"$2\"/ $file
		state=$((state|$?))
        done
	[ $state -ne 0 ] && log "Can't modify LB healthcheck file: $file"
}

function waiting_process_to_finish {
        declare -i cloop=0
        declare -i cur=$(pgrep -c -f $1)
        while [ $cur -ne 0 ] && [ $cloop -lt $MAX_RETRIES ]; do
                sleep 1
                echo -n '.'
                cur=$(pgrep -c -u root -f $1)
                let cloop+=1
        done
        echo
}

function test_http_service {
	find /etc/apache2/sites-enabled/ | while read line;
	do
		 grep ServerName $line|awk '{print $2}'
	done |while read vhost;
	do
		log "Test service $HEALTHCHECK_FILE_SUFFIX for vhost: $vhost "
		curl -s --header "Host: $vhost" http://localhost/$HEALTHCHECK_FILE_SUFFIX|grep -q OK || { echo 'FAIL'; return 1; } && { echo 'OK'; }
	done
}

function main {
	echo "[$(date)] $HOSTNAME: Starting safe restart of apache/PHP ..."

	HEALTHCHECK_FILES=$(find $HEALTHCHECK_BASEDIR -xdev -path *$HEALTHCHECK_FILE_SUFFIX|xargs)
	[ -z "$HEALTHCHECK_FILES" ] && log_and_exit_withouterror "Nothing to do : No healtcheck files found !"

	# Disable real server from LB
	change_loadbalancer_state OK FAIL
	log "Sleeping 5 seconds"
	sleep 5

	### STOP ###
	log "Stopping apache "
	$APACHECTL graceful-stop
	waiting_process_to_finish $APACHE2
	cur=$(pgrep -xfc -u root $APACHE2)
	[ $cur -ne 0 ] && log_and_exit_witherror "Timeout. Can't stop apache. PLEASE CHECK."

	log "Stopping PHP FPM"
	/etc/init.d/php5-fpm stop
	waiting_process_to_finish $PHP5FPM
        cur=$(pgrep -xfc -u root $PHP5FPM)
        [ $cur -ne 0 ] && log_and_exit_witherror "Timeout. Can't stop PHP. PLEASE CHECK."
	proc_to_clean=$(pgrep -xfl $PHP5FPM -P 1)
	if [ -n "$proc_to_clean" ]; then
		log "WARNING: Force a cleaning of residual processus"
		pkill -9 -xf $PHP5FPM -P 1
	fi

	### restart ###
	log "Restart PHP & Apache"
	$INIT_PHP start && $INIT_APACHE2 start
	[ $? -ne 0 ] && log_and_exit_witherror "Can't start Apache/PHP. PLEASE CHECK."

	# Enable real server from LB
	change_loadbalancer_state FAIL OK

	# Tests
	test_http_service
	[ $? -ne 0 ] && log_and_exit_witherror "Services seem to be offline. PLEASE CHECK."
}



############
### MAIN ###
############

[ $(id -u) -eq 0 ] || log_and_exit_witherror "Must be root"
[ "$(echo $HOSTNAME|cut -d'.' -f1|sed s/[0-9]/x/g)" == "webxx" ] || log_and_exit_witherror "This server is not a WEB server"
[ -f $LOCK_FILE ] && log_and_exit_witherror "Lock file is present: $LOCK_FILE. Abort."

trap myExit EXIT
touch $LOCK_FILE

main
exit 0
