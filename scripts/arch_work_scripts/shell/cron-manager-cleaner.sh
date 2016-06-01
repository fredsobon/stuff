#!/bin/sh
# Kill cron-manager processes older than 12h
# Maxime Guillet - Mon, 09 Dec 2013 15:57:19 +0100

kill_old_processes() {
	OLD_PID=$(find /proc/ -maxdepth 1 -type d -name '[0-9]*' -mmin +720 -printf "%U %f\n" 2>/dev/null | awk '$1>1000 && $1<65530 && $1!=6355 {print $2}')

	[ -n "$OLD_PID" ] && kill $1 $OLD_PID >/dev/null 2>&1
}

kill_old_processes -15
sleep 10
kill_old_processes -9

exit 0
