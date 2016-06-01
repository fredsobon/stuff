#!/bin/sh
# Maxime Guillet - Tue, 15 Apr 2014 16:54:47 +0200

DIR=/mnt/share/em_traces_front
COMPRESS=10
DELETE=365

for folder in $DIR/*/ ; do
	# Suppression
	find $folder -type f -mtime +$DELETE -delete
	find $folder -mindepth 1 -type d -empty -exec rmdir {} \; >/dev/null 2>&1

	# Compression
	find $folder -ignore_readdir_race ! -name '*.bz2' -type f -mtime +$COMPRESS -exec bzip2 {} \;
done
