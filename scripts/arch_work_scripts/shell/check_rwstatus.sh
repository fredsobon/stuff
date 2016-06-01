#!/bin/sh
# vim: ts=4 sw=4
#
# Author: Maxime Guillet
#
# Last Updated by:
#        Maxime Guillet - Tue, 27 Nov 2012 15:44:12 +0100
#


## FUNCTIONS ##

usage() {
	echo "Usage: $(basename $0) [-h] -g|-n|-s <OID>"
}

snmp_get() {
	case "$1" in
		0)
			echo "$BASEOID.$1"
			echo 'INTEGER'
			echo "$CHECK_STATUS"
			;;
		1)
			echo "$BASEOID.$1"
			echo 'STRING'
			echo "$CHECK_MSG"
			;;
	esac
}

check_aggr_return() {
	check_status=$1
	check_msg="$2"
	if [ ${check_status} -ge $CHECK_STATUS ]; then
		[ -n "$CHECK_MSG" ] && CHECK_MSG="${check_msg} - ${CHECK_MSG}" || CHECK_MSG="${check_msg}"
		CHECK_STATUS=${check_status}
	else
		[ -n "$CHECK_MSG" ] && CHECK_MSG="${CHECK_MSG} - ${check_msg}" || CHECK_MSG="${check_msg}"
	fi
}

check_tree() {
	CHECK_STATUS=0

	# Check the cron before the information tree
	if [ -e "/tmp/cron_rwstatus.lock" ] && [ $(find '/tmp/cron_rwstatus.lock' -mtime +1 2>/dev/null | wc -l) -ge 1 ]; then
		CHECK_STATUS=1
		CHECK_MSG='cron lockfile for rwstatus.sh is older than 1 day, cron seems to be blocked.'
		return $CHECK_STATUS
	fi

	for file in $(find "$RW_TREE" -type f 2>/dev/null); do
		status=$(cut -d : -f1 "$file")
		msg="$(cut -d : -f2 "$file")"

		if [ "$status" -gt 0 ]; then
			check_aggr_return "$status" "$msg"
		fi
	done

	[ -z "$CHECK_MSG" ] && CHECK_MSG='OK'
	return $CHECK_STATUS
}



## VARIABLES ##

MODE=
BASEOID='.1.3.6.1.4.1.38673.1.16'

RW_TREE='/usr/local/e-merchant/var/rwstatus'


## MAIN ##

[ $# -lt 1 ] && { usage; exit 0; }

while getopts 'gnsh' option; do
	case "$option" in
		# snmp
		g) MODE='get' ;;
		n) MODE='next' ;;
		s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;

		# others
		h) { usage; exit 0; } ;;
	esac
done

shift $(($OPTIND-1))


# Check for requested OID
OID=$1

if [ -n "$MODE" ] && ! (echo $OID | grep -qE "^$BASEOID"); then
	echo "Error: base OID must begin with $BASEOID" >&2
	exit 1
fi

# Check the information tree
check_tree

# Answer to OID
case ${OID#$BASEOID} in
	'')
		if [ "$MODE" = 'next' ]; then
			snmp_get 0
		fi
		;;
	.0)
		if [ "$MODE" = 'get' ]; then
			snmp_get 0
		else
			snmp_get 1
		fi
		;;
	.1)
		if [ "$MODE" = 'get' ]; then
			snmp_get 1
		fi
		;;
esac

exit 0
