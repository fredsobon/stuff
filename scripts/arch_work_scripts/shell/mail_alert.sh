#!/bin/bash
# script by nate campi <nate@campin.net>
# this script will send out an email alert no more
# often than every half hour - provided you supply the same
# argument to it for the "ALERT_MESSAGE"
#
#  - use it however you want - freeware
#
# The first argument "ALERT_MESSAGE" needs to be one word -
# it is the name used for the file that's used to measure how long it
# has been since this alert was last triggered. It is also the subject
# of the email message, so make it descriptive.
#
# this should work on any unix-like OS, if you fix the paths - 
# as written it works on redhat linux 7.0.
#

if [ $# -ne 3 ]; then
	echo "Usage: $0 ALERT_MESSAGE GRACE_PERIOD email@address" >&2
	exit 1
fi

REGEX="$1"
REGEX_FILE="/tmp/$REGEX"
GRACE_PERIOD=$2
MAILTO="$3"

while read LOGLINE ; do
	DATE_NOW=$(/bin/date +%s)

	if [ -f "$REGEX_FILE" ]; then
		THROTTLE_FILE_MTIME=$(stat -t "$REGEX_FILE" -c %Y)

		if [ $(expr $DATE_NOW - $THROTTLE_FILE_MTIME) -lt $GRACE_PERIOD ]; then
			# our work here is done
			continue
		else
			touch "$REGEX_FILE"
		fi
	else
		touch "$REGEX_FILE"
	fi
	echo ${LOGLINE/+([0-9<>])} | /usr/bin/mail -s "Log Alert: $REGEX" $MAILTO
done
