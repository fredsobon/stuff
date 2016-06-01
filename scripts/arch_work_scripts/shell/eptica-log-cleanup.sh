#!/bin/sh
# Author: m.guillet@pixmania-group.com
# Script to cleanup eptica folder log

LOGDIR=/var/log/eptica

# Remove empty files
find "$LOGDIR" -maxdepth 1 -type f -name '*.log' -mtime +1 -empty -delete

# Remove very old zip files
find "$LOGDIR" -maxdepth 1 -type f -name '*.zip' -mtime +25 -delete

# Zip old files
for srcfile in $(find "$LOGDIR" -maxdepth 1 -type f -name '*.log' -mtime +1) ; do
	dstfile="${srcfile%.log}.zip"
	zip -m $dstfile $srcfile >/dev/null
	chown tomcat7.tomcat7 $dstfile
done
