#!/bin/sh
# Maxime Guillet - lun., 03 oct. 2011 17:04:24 +0200

usage() {
	echo "$(basename $0) <check command>"
}


. /usr/lib/nagios/plugins/utils.sh || exit 3

[ $# -eq 0 ] && { usage; exit 3; }


COMMAND=$($*)
RET=$?

[ "$RET" -eq "$STATE_CRITICAL" ] && RET=$STATE_WARNING

echo "$COMMAND"
exit $RET
