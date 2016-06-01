#!/bin/sh
LOCK_FILE=/tmp/rotate_remote_logs.running
# "Securely" restart syslog-ng to force closing open files
# see https://jira.e-merchant.com/browse/INFINC-10275
service syslog-ng stop >/dev/null
TIMEOUT=60
while [ $TIMEOUT -gt 0 ] 
do
	service syslog-ng restart >/dev/null
	sleep 5
	service syslog-ng status >/dev/null

	if [ $? -eq 0 ]
	then
		break
	fi
	TIMEOUT=$(( $TIMEOUT - 5 ))
done

/usr/bin/renice -n 7 -p $$
/usr/bin/ionice -c 3 -p $$

if [[ -f ${LOCK_FILE} ]] ; then
    exit
fi
touch ${LOCK_FILE} 

# Compress old log files
#find /var/log/remote/ -type f -mtime +2 -name "*.log" -exec pbzip2 -f -9 -p4 {} \;
find /var/log/remote/ -type f -mtime +2 -name "*.log" -exec gzip -9 {} \;

# Purge logs older than 365 days
find /var/log/remote/ -type f -mtime +365 -delete

# Purge ws-stat logs older than 60 days
find /var/log/remote/*/ws-stat/ -type f -mtime +60 -delete

# Delete empty directories
find /var/log/remote/ -type d -mtime +2 -empty -delete

# Reload syslog-ng
service syslog-ng reload >/dev/null

rm -f ${LOCK_FILE} 
