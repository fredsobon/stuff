#!/usr/bin/env sh

# Auteur : Maxime Guillet (27.10.2014)
# Aide au debug iSCSI

LOGDIR='/var/log/iscsi_traces'
FILE="${LOGDIR}/$(date +%Y%m%d-%H).log"
HEAD="[$(hostname) - $(date +%Y%m%d-%H%M%S)] "

check_standard() {
	echo '# uptime'
	uptime

	echo '# ping'
	ping -c 6 -W 1 -i 0.5 -n 10.3.115.3
	ping -c 6 -W 1 -i 0.5 -n 10.3.115.4
	ping -c 6 -W 1 -i 0.5 -n 10.3.115.1
	ping -c 6 -W 1 -i 0.5 -n 10.3.115.2

	echo '# proc number'
	ls -d /proc/[0-9]* | wc -l

	echo '# arp -n'
	/sbin/arp -n

	echo '# netstat -antupe | grep iscsid'
	netstat -antupe | grep iscsid
}

check_iscsi() {
	echo '# iscsiadm -m session'
	/sbin/iscsiadm -m session

	echo '# iscsiadm -m node'
	/sbin/iscsiadm -m node

	echo '# iscsiadm -m session -s'
	/sbin/iscsiadm -m session -s
}

[ ! -d ${LOGDIR} ] && mkdir -p ${LOGDIR}

check_standard 2>&1 | sed "s/^/$HEAD/" >>$FILE
check_iscsi 2>&1 | sed "s/^/$HEAD/" >>$FILE
find ${LOGDIR} -type f -mtime +30 -delete
