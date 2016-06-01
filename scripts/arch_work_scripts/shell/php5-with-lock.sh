#!/bin/sh

[ $# -lt 1 ] && { echo "missing php file in argument." >&2 ; exit 1 ; }

PHPCRONFILE="$1"
NAME=$(basename "$PHPCRONFILE" .php)
USER="$(whoami)"

LOCK="/var/lock/$USER-$NAME"

my_exit() {
	rm -f "$LOCK"
	echo "forcing exit..." >&2
	exit 1
}

trap 'my_exit' INT TERM HUP

[ -e "$LOCK" ] && { echo "script $PHPCRONFILE is running." >&2 ; exit 1 ; }

touch "$LOCK" && php5 "$PHPCRONFILE"
RET=$?

rm -f "$LOCK"

exit $RET
