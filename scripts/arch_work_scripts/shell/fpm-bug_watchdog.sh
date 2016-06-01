#!/bin/bash


# Author: dlarquey, fcauvet

# Frontal watchdog : Automatic grace full restart of apache/PHP FPM
#
# + This script tests a crash of the master php proceses. (No php FPM master process but some childs are present)
# + This scripts tests last modification date of the bugfpm file $BUG_FILE which is periodically updated by the load balancer test.
# Once last modification date of the file $BUG_FILE is older than $MIN_AGE_TIME_TO_RESTART, then an applicative restart is performed
# Before doing this, it could launch $FRONTAL_CHECK_SCRIPT script to ensure that frontal is in dead condition


# See log file $LOG_FILE
# Any error and restart actions are reported and mailed
# One mail is sent one time for each kind of error until service coming up again.

BUG_FILE=/tmp/bug-fpm.log

script_name=$(basename $0)
script_name=${script_name%.*}
LOG_FILE=/var/log/${script_name}.log
LOCK_FILE=/tmp/${script_name}.lock
DOING_RESTART_FILE=/tmp/${script_name}.restart_in_progress

# Be careful :
# Between MIN_AGE_TIME_TO_RESTART and MAX_AGE_TIME_TO_RESTART, a restart action will be attempted on each run of this script if bugfpm file is not up to date
MIN_AGE_TIME_TO_RESTART=1 	# minutes
MAX_AGE_TIME_TO_RESTART=15	# minutes
KILL_LIMIT_TIME=300		# seconds. Try to kill processes during this interval. Abort if it can't.
# Be careful : Once KILL_LIMIT_TIME is reached, this script exit with error and the next check won't try to restart if pid file can't be found !!!

MAX_WAITTIME_BEFORE_RESTART=10	# seconds. random sleep just before restarting

APACHE2CTL=/usr/sbin/apache2ctl
PHP_STARTSCRIPT=/etc/init.d/php5-fpm

# Proc & PID
PROC_APACHE=/usr/sbin/apache2
PROC_PHP=/usr/sbin/php5-fpm
PIDFILE_PHP=/var/run/php5-fpm.pid
PIDFILE_APACHE=/var/run/apache2.pid

#Nbre d'erreur
VALUE_RESTART=5

#### Output ###
DEBUG=true

### Mail ###
# send mail only on cron mode
SEND_MAIL=
MAIL_FILE=
SEND_TO='it.prod.admin@pixmania-group.com'
# History mail feature avoid sending the same error mail on each run
MAIL_HISTORY=/tmp/${script_name}.mail_history

### control action ###
EXIT_WITHOUT_ERROR=true				# normal exit
EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE=false	# EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE => EXIT_WITHOUT_ERROR. true if EXIT_WITHOUT_ERROR && !CALL_RESTART_ACTION
CALL_RESTART_ACTION=false
END_RESTART_ACTION=false			# END_RESTART_ACTION => CALL_RESTART_ACTION

# 3 exit states :
# ! EXIT_WITHOUT_ERROR: init error or error during a restart action
# EXIT_WITHOUT_ERROR = (CALL_RESTART_ACTION && END_RESTART_ACTION) || EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE
# EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE : EXIT_WITHOUT_ERROR && !CALL_RESTART_ACTION


#################
### functions ###
#################

function usage() {
	echo "Usage: $(basename $0)"
	echo "Watchdog script: Automatic grace full restart of apache/php FPM"
}


function log() {
	local date=$(date)
	echo "[$date] $@"
	[ -n "$SEND_MAIL" ] && [ $SEND_MAIL == 'true' ] && [ -n "$MAIL_FILE" ] && { echo "[$date] $@" >>$MAIL_FILE; }
}

function log_error() {
	local date=$(date)
	echo "[$date] [ERROR] $@" >&2
	[ -n "$SEND_MAIL" ] && [ $SEND_MAIL == 'true' ] && [ -n "$MAIL_FILE" ] && { echo "[$date] $@" >>$MAIL_FILE; }
}

function log_warning() {
	local date=$(date)
        echo "[$date] [WARNING] $@" >&2
        [ -n "$SEND_MAIL" ] && [ $SEND_MAIL == 'true' ] && [ -n "$MAIL_FILE" ] && { echo "[$date] $@" >>$MAIL_FILE; }
}

# send mail is called on exit
function send_mail() {
	local PREFIX

	([ -z "$MAIL_FILE" ] || [ ! -f $MAIL_FILE ]) && return 0

	PREFIX=
	SUFFIX=
	if [ $EXIT_WITHOUT_ERROR != true ]; then
		PREFIX='[WARNING]'
		SUFFIX='initialization error'
	fi

	if [ $CALL_RESTART_ACTION == 'true' ]; then
		PREFIX='[RESTART_ACTION]'
		SUFFIX='Service is UP and RUNNING'
		[ $END_RESTART_ACTION != 'true' ] && { PREFIX='[ERROR][RESTART_ACTION]'; SUFFIX='Error during a restart action'; }
	fi

	if [ -n "$SEND_MAIL" ] && [ $SEND_MAIL == 'true' ] && [ -s $MAIL_FILE ]; then
		# Before sending mail, it checks in MAIL_HISTORY file if it was already done since last exit without error
		local md5=$(cat $MAIL_FILE|sed 's/^\[[^\[]*\][[:blank:]]*//g'|md5sum|awk '{print $1}')

		if [ ! -f $MAIL_HISTORY ] || ! grep -q MD5=$md5 $MAIL_HISTORY; then
			# Do mail history
			echo "[$(date)] Send mail. (No timestamp)MD5=$md5" >>$MAIL_HISTORY

			log "Send mail to: $SEND_TO"
			[ $EXIT_WITHOUT_ERROR != true ] && log "--- LAST MAIL SENT FOR THIS KIND OF ERROR UNTIL NEXT SUCCESSFULL CHECK ---"

			mail -s "[$script_name][$(hostname -f|cut -d. -f1-4)]${PREFIX} $SUFFIX" $SEND_TO <$MAIL_FILE

		else
			[ $DEBUG == 'true' ] && log_error "Mail was already sent (MD5=$md5)"
		fi
	fi
}

function local_exit() {
	rm -f $LOCK_FILE

	if [ $EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE == 'true' ]; then
		# Don't send mail if EXIT_WITHOUT_ERROR && !CALL_RESTART_ACTION
		# Remove MAIL_HISTORY to enable send mail the next time an error occured
		[ -f $MAIL_HISTORY ] && rm -f $MAIL_HISTORY
	else
		# Send mail only if !EXIT_WITHOUT_ERROR || CALL_RESTART_ACTION
		send_mail
	fi
	[ -f $MAIL_FILE ] && rm -f $MAIL_FILE
}


# beurk
# return a random number as 0<=random<limit
# max limit is 256
function random() {
	local random limit
	typeset -i random limit
	limit=256
	[ -n "$1" ] && limit=$1

	if [ -n "$RANDOM" ]; then
		random=$RANDOM
	else
		random=$(head /dev/urandom 2>/dev/null|hexdump -n1 -e'/1 "%u"')
	fi

	[ -z "$random" ] && { log_error "Can't initialize randomizer"; random=0 ; }

	return $((random%limit))
}

function check_binaries() {
	[ -f $PROC_APACHE ]	|| { log_error "Can't find apache daemon. =>EXIT."; exit 1; }

	[ -x $APACHE2CTL ]	|| { log_error "Can't execute apache start script: $APACHE2CTL. =>EXIT."; exit 1; }
	[ -x $PHP_STARTSCRIPT ]	|| { log_error "Can't execute php start script: $PHP_STARTSCRIPT. =>EXIT."; exit 1; }
}

function check_pidfile() {
        [ -f $PIDFILE_PHP ]     || { log_error "Can't find PHP PID file. =>EXIT."; exit 1; }
        [ -f $PIDFILE_APACHE ]  || { log_error "Can't find apache PID file. =>EXIT."; exit 1; }
}

function check_pidfile_apache() {
	local pid name
	typeset -i pid

   pid=$(cat $PIDFILE_APACHE)
   name=$(basename $PROC_APACHE)
   ps -au root -o pid,comm |egrep -q "^[[:blank:]]*$pid"
   [ $? -ne 0 ] && return 1
   ps -au root -o pid,comm |grep -q $name
   [ $? -ne 0 ] && return 2
   ps -au root -o pid,comm |egrep "^[[:blank:]]*$pid"|grep -q $name
   [ $? -ne 0 ] && return 3

   return 0
}

# return code:
# 1 : there is no php FPM process
# 2 : there is any php processes named as expected
# 3 : the root master process identified by the pid file doesn't match the expected name
# 4 : only the root php master process has crashed
function check_pidfile_php() {
    local pid name
    typeset -i pid

	pid=$(cat $PIDFILE_PHP)
	name=$(basename $PROC_PHP)

    nr_php_root_process=$(ps a -u root -o pid,comm|grep $name|wc -l)
    nr_php_process=$(ps ax -o pid,comm|grep $name|wc -l)
    [ $nr_php_root_process -eq 0 -a $nr_php_process -ge 1 ] && return 4
 
	ps -au root -o pid,comm |egrep -q "^[[:blank:]]*$pid"
	[ $? -ne 0 ] && return 1
	ps -au root -o pid,comm |grep -q $name
	[ $? -ne 0 ] && return 2
	ps -au root -o pid,comm |egrep "^[[:blank:]]*$pid"|grep -q $name
	[ $? -ne 0 ] && return 3

	return 0
}

function check_running_front_process() {

	check_pidfile_apache
	ret=$?
	[ $ret -eq 1 ] && { log_error "WTF? apache pidfile doesn't match a running process ($PIDFILE_APACHE) !!"; exit 1; }
	[ $ret -eq 2 ] && { log_error "WTF? Missing running apache process: $PROC_APACHE !!"; exit 1; }
	[ $ret -eq 3 ] && { log_error "WTF? apache running process doesn't match pidfile ($PIDFILE_APACHE) !!"; exit 1; }

	check_pidfile_php
	ret=$?
    [ $ret -eq 1 ] && { log_error "WTF? php FPM pidfile doesn't match a running process ($PIDFILE_PHP) !!"; exit 1; }
    [ $ret -eq 2 ] && { log_error "WTF? Missing running php FPM process: $PROC_PHP !!"; exit 1; }
    [ $ret -eq 3 ] && { log_error "WTF? php FPM running process doesn't match pidfile ($PIDFILE_PHP) !!"; exit 1; }

    # BUG PHP: the php FPM  master process has crashed
    [ $ret -eq 4 ] && { log 'No master php FPM process was found !'; restart; }

	return 0
}

function check_bugfpmfile {

    [ -f $BUG_FILE ] || return 0
	my_date=`/bin/date +"%b %e %H:%M" -d -1min`

	nb_occurence=`grep "$my_date" $BUG_FILE | wc -l`

#	[ $nb_occurence -gt $VALUE_RESTART ] && forcerestart;
	[ $nb_occurence -gt $VALUE_RESTART ] && restart;
	return 0
}

function forcerestart() {
	local pid ret c r rand
 	typeset -i pid ret c r rand

	CALL_RESTART_ACTION=true
 
 	log "--- Watchdog wake up ---"
	log "FPM BUG is active"
	log "Triggered for an applicative restart ..."

	random $MAX_WAITTIME_BEFORE_RESTART
	rand=$?
	[ $rand -ne 0 ] && { log "Sleeping random time : $rand secs ..."; sleep $rand; }
	log "-"

	# auditlog
	if [ -x $(dirname $0)/auditlog.sh ]; then
		log "Collecting stats..."
		$(dirname $0)/auditlog.sh before
	fi

	touch $DOING_RESTART_FILE

	## ACTION BEGIN
	/etc/init.d/apache2 stop
	pkill -9 apache2
	sleep 1
	pkill -9 php5-fpm
	sleep 1
	/etc/init.d/php5-fpm restart
	sleep 1
	/etc/init.d/apache2 restart

	sleep 3 
	check_running_front_process

 	log "Ready to accept clients ..."
 	rm -f $DOING_RESTART_FILE
	END_RESTART_ACTION=true

	## ACTION END

	# auditlog
	if [ -x $(dirname $0)/auditlog.sh ]; then
		log "Collecting stats..."
		$(dirname $0)/auditlog.sh after
	fi

 	return 0
	
}

#
# function: RESTART 
# 
function restart() {
 
	local pid ret c r rand
 	typeset -i pid ret c r rand

	CALL_RESTART_ACTION=true
 
 	log "--- Watchdog wake up ---"
	log "FPM BUG is active"
	log "Triggered for an applicative restart ..."

	random $MAX_WAITTIME_BEFORE_RESTART
	rand=$?
	[ $rand -ne 0 ] && { log "Sleeping random time : $rand secs ..."; sleep $rand; }
	log "-"

	# auditlog
	if [ -x $(dirname $0)/auditlog.sh ]; then
		log "Collecting stats..."
		$(dirname $0)/auditlog.sh before
	fi

	touch $DOING_RESTART_FILE

 ### stop ###

	# stop apache
	if [ -f $PIDFILE_APACHE ]; then
		pid=$(cat $PIDFILE_APACHE)

	 	log "Stopping apache ..."
	 	$APACHE2CTL graceful-stop >/dev/null
	
	 	c=0
	 	while true; do
	 		sleep 1
	 		num=$(pgrep -cP $pid)
	 		[ $num -eq 0 ] && break;
	 		c=$((c+1))
	 		[ $c -ge $KILL_LIMIT_TIME ] && { log_error "Can't stop apache. Max limit reached. =>ABORT." ; exit 1; }
	 	done
	 	log "Apache is NOW stopped."
	fi

	sleep 1
	 
 	# stop php FPM
	if [ -f $PIDFILE_PHP ]; then
		pid=$(cat $PIDFILE_PHP)

	 	log "Stopping php FPM ..."
	 	$PHP_STARTSCRIPT stop >/dev/null

	 	c=0
	 	while true; do
	 		sleep 1
	 		num=$(pgrep -cP $pid)
			[ $num -eq 0 ] && break;
	 		log_error "Forcing php FPM to terminate ..."
			kill -SIGKILL $pid
	 
	 		c=$((c+1))
	 		[ $c -ge $KILL_LIMIT_TIME ] && { log_error "Can't stop php FPM. =>ABORT." ; exit 1; }
	 	done
	fi

	#flush file
	echo "RESTART DONE --EMPTY FILE--" > $BUG_FILE
 
 ### restart ###
	log "---RESTART---"
 	# start php FPM
 	sleep 1

 	log "Starting php FPM ..."
	$PHP_STARTSCRIPT start >/dev/null

 	ret=$?
 	sleep 1
 
 	if [ $ret -eq 0 ] && [ -f $PIDFILE_PHP ]; then
 		log "php FPM is started."

 		# start apache
		sleep 2

 		log "Starting apache ..."
 		$APACHE2CTL start >/dev/null

 		[ $? -ne 0 ] && { log_error "Can't start apache. =>ABORT."; exit 1; }
 		log "Apache is started."
 	else
 		log_error "Can't start php FPM. =>ABORT."
 		exit 1
 	fi

	sleep 3 
	check_running_front_process

 	log "Ready to accept clients ..."
 	rm -f $DOING_RESTART_FILE
	END_RESTART_ACTION=true

	# auditlog
	if [ -x $(dirname $0)/auditlog.sh ]; then
		log "Collecting stats..."
		$(dirname $0)/auditlog.sh after
	fi

 	return 0
 }
 


############
### MAIN ###
############

# Protect ME !
if [ "$1" != "--I_KNOW_WHAT_I_DO" ]; then
	usage
	exit 0
fi
shift

CRON=false

if [ "$1" == "--cron" ]; then
	CRON=true
	MAIL_FILE=$(mktemp)
	SEND_MAIL=true
	exec >>$LOG_FILE
	exec 2>&1
else
	SEND_MAIL=false
fi

if [ -f $LOCK_FILE ]; then
	log_error "Lock file already exists. =>ABORT."
	exit 1
fi

# trap =>EXIT signal
trap local_exit EXIT

#
# From here, if SEND_MAIL is enabled, all messages printed with log_* functions will be mailed, except if EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE
#

# check binaries
check_binaries

which mail >/dev/null|| { log_error "Can't execute binary: mail. =>EXIT."; exit 1; }
which md5sum >/dev/null|| { log_error "Can't execute binary: md5sum. =>EXIT."; exit 1; }
which hexdump >/dev/null|| { log_error "Can't execute binary: hexdump. =>EXIT."; exit 1; }

# check bug fpm file
#[ -f $BUG_FILE ] || { echo "No file found, then no errors"; exit 1; }

touch $LOCK_FILE

# OK, we can start
if [ -f $DOING_RESTART_FILE ]; then
	log_warning "A previous restart seems to have been attempted. Bypassing process checks and try to restart again if bugfpm file is not up to date..."
	rm -f $DOING_RESTART_FILE
else
	# check pidfile
	check_pidfile
	
	# check front processes
	check_running_front_process
fi

check_bugfpmfile



# here, all is fine
# we did a success restart or nothing was done
# EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE == false if we did a successful restart
EXIT_WITHOUT_ERROR=true
[ $CALL_RESTART_ACTION != 'true' ] && EXIT_WITHOUT_ERROR_NOTHING_WAS_DONE=true

if [ -f $MAIL_HISTORY ]; then
	# History file exists => an error occured before (error mail was sent)
	log "All is NOW fine. Service is UP and RUNNING."
fi

exit 0

