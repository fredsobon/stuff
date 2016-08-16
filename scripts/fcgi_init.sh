 sites-enabled # cat  /LAPIN/script/init.d/fcgi.init 
#!/bin/bash

# Script to start and stop the fast-cgi daemons
#
# chkconfig: 2345 55 25
# description: fast-cgi
#

#Informations de configuration generiques
CONF_FILE=/LAPIN/conf/fcgi.conf
LOG_FCGI_NAME='fcgi_%s.log'
LOG_FCGI_DIR='/LAPIN/data/log/fcgi'
LOG_FCGI="${LOG_FCGI_DIR}/${LOG_FCGI_NAME}"
PHP_USER=php
PHP_GROUP=php
FPHP_5=/LAPIN/applications/php-fastcgi-5/bin/php-cgi
PHP_CHILDS=20
PHP_FCGI_MAX_REQUESTS=100000
PHP_MEMORY_LIMIT='256M'
PHP_APC_SHM_SIZE='192M'
PHP_SHORT_OPEN_TAG='Off'

#Les chemins d'acces aux programmes
KILL=/bin/kill
RM=/bin/rm
AWK=/bin/awk
ECHO=/bin/echo
GREP=/bin/grep
SED=/bin/sed
CAT=/bin/cat
SU=/bin/su
PS=/bin/ps
HEAD=/usr/bin/head
#Environnement ORACLE
#ORACLE_BASE=/usr/lib/oracle/
#ORACLE_HOME=$ORACLE_BASE/10.1.0.4/client
#LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib
#ORANLS33=$ORACLE_HOME/ocommon/nls/admin/data
#PATH=$ORACLE_HOME/bin:$PATH
NLS_LANG=French_France.UTF8
NLS_DATE_FORMAT='YYYY-MM-DD HH24:MI:SS'
NLS_NUMERIC_CHARACTERS='.,'

#Pour forcer HOSTNAME (cnx distante etc...)
HOSTNAME=`hostname`

#Pour definir un autre repertoire de config
#Les configurations special.app etant trop differentes des autres composants classic_conf.
CONFIG_ROOT="/config.special.appprod/"

export USERNAME BASH_ENV NLS_LANG NLS_DATE_FORMAT NLS_NUMERIC_CHARACTERS PHP_FCGI_CHILDREN ZEUSHOME PHP_FCGI_MAX_REQUESTS SITE_ROOT PHP_MEMORY_LIMIT PHP_APC_SHM_SIZE PHP_SHORT_OPEN_TAG HOSTNAME CONFIG_ROOT

#Modification param�tres noyaux
$ECHO 1024 65000 > /proc/sys/net/ipv4/ip_local_port_range

# Modification du file-max
$ECHO 65000 > /proc/sys/fs/file-max

#Lecture de la configuration d'un site
function read_site_conf
{
	#On doit avoir un parametre
	if [ -z $1 ]
	then
		$ECHO No server name supplied in call to read_conf
		return
	fi
	#On lit le fichier, grace � awk
	$AWK -v section=$1 -v start=0 -F = '
/^;/ { next; }
/^\[?$/ { start=0; }
/^\[([^\]]+)\]$/ { if ($1 == "["section"]") { start=1; next } }
/^.+$/ { if (start == 1) { print toupper($1) "=" $2 "\n" ; } }
		' $CONF_FILE
}

#Lecture de la liste des sites
function read_sites
{
	$GREP '\[.*\]' $CONF_FILE | $SED -e 's/^\[\(.*\)\]$/\1/'
}

#Demarrage d'un site
function start_site
{
	if [ -z "$1" ]
	then
		$ECHO Wrong number of arguments in call to start_site
		return 1;
	fi
	#On efface les arguments, par prudence
	unset EXTRA PID PORT FCGI CHILDS PHPVERSION
	#Le separateur de commande, redefini apr�s backup
	OLDIFS=$IFS
	IFS=$'\t\n'
	#On lit les infos et on les declare
	for i in $(read_site_conf $1);
	do
		declare -x $i
	done
	IFS=$OLDIFS
	#Tests de param�tres standard
	if [ -z "$PID" -o -z "$PORT" ]
	then
		$ECHO Bad or no entries in configuration file for $1
		return 1;
	fi
	#Si ca tourne deja, erreur
	if [ -f $PID ]; then
		echo "Checking pid $PID presency"
		pid=`cat $PID`
		#echo "pid for $1 = $pid"
		#echo "on check la presence de process ecoutant sur le port $PORT"
		presency=`ps ax | grep "127.0.0.1:$PORT" | grep -v grep | awk '{print $1}'`
		if [ ! -z "$presency" ]; then
			$ECHO "$1: already running"
		else
			echo "Pid file $PID present, but no process with this pid"
			echo "removing pid file"
			rm -f $PID

			# after restopping the handler (removing pid files), normal procedure to start the handler
			#On affiche ce qui se passe
			$ECHO "$1 Starting PHP Version[$PHPVERSION]"
			if [ $PHPVERSION -eq 5 ]; then
				FCGI=$FPHP_5
			else
				FCGI=$FPHP_4
			fi

			if [ ! -d "$LOG_FCGI_DIR" ] ; then
                        	mkdir -p $LOG_FCGI_DIR
	                        chown php.php $LOG_FCGI_DIR
        	                chmod 755 $LOG_FCGI_DIR
                	fi

			LOG_FCGI_FILE=$(printf "$LOG_FCGI" $1)
			CMD="PHP_FCGI_CHILDREN=${CHILDS:-$PHP_CHILDS} nohup $FCGI -b 127.0.0.1:$PORT $EXTRA  >${LOG_FCGI_FILE} 2>&1 &"
			$SU -m -c "$CMD" $PHP_USER 
			$SU -m -c "$PS -ef | $GREP $FCGI | $GREP \":$PORT \" | $AWK '{print \$2}'| $HEAD -1  > $PID" $PHP_USER
		fi
	else
		#On affiche ce qui se passe
		$ECHO "$1 Starting PHP Version[$PHPVERSION]"
		if [ $PHPVERSION -eq 5 ]; then
         		FCGI=$FPHP_5
		else
			FCGI=$FPHP_4
		fi

        	if [ ! -d "$LOG_FCGI_DIR" ] ; then
			mkdir -p $LOG_FCGI_DIR
			chown php.php $LOG_FCGI_DIR
			chmod 755 $LOG_FCGI_DIR
        	fi

		LOG_FCGI_FILE=$(printf "$LOG_FCGI" $1)
		CMD="PHP_FCGI_CHILDREN=${CHILDS:-$PHP_CHILDS} nohup $FCGI -b 127.0.0.1:$PORT $EXTRA  >${LOG_FCGI_FILE} 2>&1 &"
		$SU -m -c "$CMD" $PHP_USER 
		$SU -m -c "$PS -ef | $GREP $FCGI | $GREP \":$PORT \" | $AWK '{print \$2}'| $HEAD -1  > $PID" $PHP_USER
	fi
}

#arret d'un site
function stop_site
{
	if [ -z "$1" ]
	then
		$ECHO Wrong number of arguments in call to start_site
		return 1;
	fi
	#On efface les arguments, par prudence
	unset EXTRA PID PORT FCGI CHILDS PHPVERSION
	#Le separateur de commande, redefini apr�s backup
	OLDIFS=$IFS
	IFS=$'\t\n'
	#On lit les infos et on les declare
	for i in $(read_site_conf $1);
	do
		declare $i
	done
	IFS=$OLDIFS
	#Tests de param�tres standard
	if [ -z "$PID" ]
	then
		$ECHO Bad or no entries in configuration file for $1
		return 1;
	fi
	#On affiche ce qui se passe
	if [ -f $PID ]
	then
		$KILL `$CAT $PID`
		$RM -f $PID
		$ECHO "$1 stopped"
	else
		$ECHO "$1 is not running"
	fi
}

case "$1" in
	'start')
		shift 1;
		if [ $# -eq 0 ]
		then
			for site in $(read_sites)
			do
				start_site $site
			done
		else
			for site in $@
			do
				start_site $site
			done
		fi
		;;
	'stop')
		shift 1;
		if [ $# -eq 0 ]
		then
			for site in $(read_sites)
			do
				stop_site $site
			done
			sleep 1
                        #pids=`pidof "/LAPIN/applications/php-fastcgi-${PHPVERSION}/bin/php-cgi"`
                        pids=`ps ax | grep php-fastcgi | grep -v grep | awk '{print $1}'`
                        echo "pids = $pids"
                        if [ -z "$pids" ]; then
                                echo "No remaining processes"
                        else
                                echo "Killing remaining processes $pids"
                                kill -6 $pids
                                pids=`pidof "/LAPIN/applications/php-fastcgi-${PHPVERSION}/bin/php-cgi"`
                                if [ ! -z $pids ]; then
                                       kill -9 $pids
                                fi
                        fi
		else
			for site in $@
			do
				stop_site $site
				port=`grep -A5 $site $CONF_FILE | grep port | cut -d"=" -f2`
				phpvers=`grep -A5 $site $CONF_FILE | grep phpversion | cut -d"=" -f2`
				echo "Stopping site with port = $port"
				pids=`ps ax | grep "/LAPIN/applications/php-fastcgi-${phpvers}/bin/php-cgi" | grep "127.0.0.1:$port" | grep -v grep | awk '{print $1}'`
				echo "pids = $pids"
				if [ -z "$pids" ]; then
					echo "No remaining processes for site $1"
				else
					echo "Killing remaining processes $pids"
					kill -6 $pids
					pids=`ps ax | grep "/LAPIN/applications/php-fastcgi-${phpvers}/bin/php-cgi" | grep "127.0.0.1:$port" | grep -v grep | awk '{print $1}'`
					if [ ! -z $pids ]; then
						kill -9 $pids
					fi
				fi
			done
		fi
		;;
	'restart')
		shift 1;
		if [ $# -eq 0 ]
		then
			for site in $(read_sites)
			do
				stop_site $site
				start_site $site
			done
		else
			for site in $@
			do
				stop_site $site
				start_site $site
			done
		fi
		;;
	*)
		$ECHO "Usage: $0 (start|stop|restart) [siteName ...]"
		;;
esac

