#!/bin/sh
# Author: m.guillet@pixmania-group.com
# Script to cleanup sinequa folder log

LOGDIR=/var/log/eptica/sinequa

# Remove very old compressed files
find "$LOGDIR" -maxdepth 1 -type f -regex '.*\.\(gz\|alive\)$' -mtime +25 -delete

# Compress old files
for srcfile in $(find "$LOGDIR" -maxdepth 1 -type f -regex '.*/iI[0-9].*\.\(log\|idx\)$' -mtime +1); do
	chmod -x "$srcfile"
	gzip -9 "$srcfile"
done
