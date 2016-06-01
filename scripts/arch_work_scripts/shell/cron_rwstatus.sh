#!/bin/sh
# vim: ts=4 sw=4
#
# Author: Maxime Guillet
#
# Last Updated by:
#        Maxime Guillet - Tue, 27 Nov 2012 14:00:29 +0100
#


## FUNCTIONS ##

myexit() {
	[ -f "$LOCK" ] && rm -f "$LOCK"
}

clean_tree() {
	# Clean file older than 1 days into the tree

	rm -rf "$RW_TREE"
	mkdir -p "$RW_TREE"

}

set_value() {
	# Set value into the tree

	[ "$DEBUG" -ge 1 ] && echo  "..result for $mount is $2"

	var_file="$RW_TREE/$(echo "$mount" | sed 's;/;@;g')"

	echo "$1:$2" > "$var_file"
}

check_mountpoint() {
	# Test every RO/RW check on the mount point

	[ $# -ne 1 ] && { echo 'Missing mountpoint parameter' >&2; return 1; }

	local write_dir="$1"

	[ "$DEBUG" -ge 1 ] && echo  ".check $write_dir"

	# Check directory type ($write_dir/. to be sure to be inside directory)
	if [ ! -d "$write_dir/." ]; then
		set_value 2 "$write_dir does not exist" && return 2
	elif [ ! -w "$write_dir/." ]; then
		set_value 3 "$write_dir is not writable by $USER" && return 3
	fi

	# Try to create a temporary file
	local temp_file="$(mktemp "$write_dir"/rwstatus.XXXXXXX 2>/dev/null)"
	if [ $? -ne 0 ]; then
		set_value 4 "mktemp failed in $write_dir" && return 4
	fi

	# Try to write in the temporary file
	local storeval="$$"
	echo "$storeval" > "$temp_file"
	if [ $? -ne 0 ]; then
		rm -f "$temp_file"
	    set_value 5 "write error in $temp_file" && return 5
	fi

	# Try to read the temporary file
	if [ "$(cat "$temp_file")" != "$storeval" ]; then
		rm -f "$temp_file"
		set_value 6 "$temp_file has wrong contents" && return 6
	fi

	rm -f "$temp_file"
	set_value 0 'OK' && return 0
}



## VARIABLES ##

LOCK="/tmp/$(basename $0 .sh).lock"
DEBUG=0

CHECK_FSTYPE='ext4|xfs'
RW_TREE='/usr/local/e-merchant/var/rwstatus'


## MAIN ##

trap 'myexit' INT TERM

if [ -e "$LOCK" ]; then
	echo "Script $(basename $0) is running." >&2
	exit 1
else
	echo "$$" > "$LOCK"
fi

clean_tree

MOUNTPOINT=$(awk "\$3~/$CHECK_FSTYPE/ {print \$2}" /etc/mtab)

IFS='
'

for mount in $MOUNTPOINT; do
	check_mountpoint "$mount"
done

rm -f "$LOCK"

exit 0





