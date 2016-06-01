#!/bin/bash
# vim: ts=4 sw=4 et
#
# check-mount.sh: Vincent Batoufflet <vbatoufflet@e-merchant.com>
#                 Wed, 31 Oct 2012 13:15:29 +0100
#

# Defaults
CONF='/etc/snmp/check-mount.conf'
BASEOID='.1.3.6.1.4.1.38673.1.8'
MODE=''
EXCLUDE=''

# Functions
parse_file() {
	awk '$1 !~ /^(#| *$)/ && $3 !~ /^(swap|rootfs|sysfs|proc|devtmpfs|devpts|tmpfs|fusectl|debugfs|securityfs|rpc_pipefs|binfmt_misc|usbfs|autofs|nfsd|xenfs)$/ { print $1 " " $2 }' $1 | while read DEVICE MOUNTPOINT
	do

	# Ignore excluded mount points
	if [ -n "$EXCLUDE" ] && [[ $MOUNTPOINT =~ $EXCLUDE ]]
	then
		continue
	fi

	# Remove trailing slashes
	if [ $DEVICE != '/' ]
	then
		DEVICE=${DEVICE%/}
	fi
	if [ $MOUNTPOINT != '/' ]
	then
		MOUNTPOINT=${MOUNTPOINT%/}
	fi

	# If root devices is "/dev/root", read it from "/proc/cmdline"
	if [ $DEVICE = '/dev/root' ]
	then
		DEVICE=`sed 's/^.*root=\([^ ]\+\).*$/\1/' /proc/cmdline`
	fi

	# Manage UUID devices
	if [[ $DEVICE =~ ^UUID= ]]
	then
		DEVICE="/dev/disk/by-uuid/${DEVICE#UUID=}"
	fi

	# Manage symbolic links
	if [[ $DEVICE =~ ^/ ]]
	then
		if [ -L $DEVICE ]
		then
			DEVICE=`readlink -f $DEVICE`
		fi
	fi

	echo $DEVICE $MOUNTPOINT
	done | sort
}

print_usage() {
	cat <<EOF
Usage: $(basename $0) [-h] {-g|-n|-s} OID [VALUE]

Options:
   -g  get value
   -h  display this help and exit
   -n  get next value
   -s  set value
EOF
}

snmp_get() {
	case "$1" in
	1)
		echo -e "$BASEOID.$1\nINTEGER"
	
		if grep -q '^-' $TMPDIR/diff
		then
			# Missing mounts (-) trigger critical alerts
			echo 2
		elif grep -q '^+' $TMPDIR/diff
		then
			# Undeclared mounts (+) trigger warning alerts
			echo 1
		else
			echo 0
		fi
		;;
	2)
		echo -e "$BASEOID.$1\nSTRING"
		if [ $(cat $TMPDIR/diff | wc -l) -ne 0 ]; then
			 sed -e ':a;N;$!ba;s/\n/; /g' $TMPDIR/diff
		else
			echo ''
		fi
		;;
	esac
}

# Parse for command-line arguments
while getopts 'ghns' options; do
	case "$options" in
	g) MODE='get' ;;
	n) MODE='next' ;;
	s) echo 'Warning: SET command not implemented' >&2; exit 1 ;;
	h) print_usage; exit 0 ;;
	*) print_usage; exit 1 ;;
	esac
done

shift $(($OPTIND-1))

if [ $# -ne 1 -o -z "$MODE" ]; then
	print_usage
	exit 1
fi

# Check for requested OID
OID=$1

if ! (echo $OID | grep -qE "^$BASEOID"); then
	echo "Error: base OID must begin with $BASEOID" >&2
	exit 1
fi

# Include configuration file if it exists
if [ -f "$CONF" ]
then
	. "$CONF"
fi

TMPDIR=$(mktemp -d)

# Get mounts from "mount" command
mount | sed -e 's/ on / /' -e 's/ type / /' >$TMPDIR/mount.out

# Parse mount files
parse_file /etc/fstab >$TMPDIR/fstab
parse_file $TMPDIR/mount.out >$TMPDIR/mounts

diff -U 0 $TMPDIR/fstab $TMPDIR/mounts | grep -v -E '^(---|\+\+\+|@@)' > $TMPDIR/diff

case ${OID#$BASEOID} in
	'')
	if [ "$MODE" == 'next' ]; then
		snmp_get 1
	fi
	;;
	.1)
	if [ "$MODE" == 'get' ]; then
		snmp_get 1
	else
		snmp_get 2
	fi
	;;
	.2)
	if [ "$MODE" == 'get' ]; then
		snmp_get 2
	fi
	;;
esac

rm -rf $TMPDIR
