#!/bin/sh
# Maxime Guillet - Tue, 15 Apr 2014 16:54:47 +0200

DIR=/mnt/share/em_traces_wsint
COMPRESS=10
DELETE=365

CLIENT_FOLDER=temp-wsint-client
CLIENT_COMPRESS=30
CLIENT_DELETE=$DELETE

for folder in $DIR/*/ ; do
	[ "$(basename $folder)" = "$CLIENT_FOLDER" ] && continue

	# Suppression
	find $folder -type f -mtime +$DELETE -delete
	find $folder -mindepth 1 -type d -empty -exec rmdir {} \; >/dev/null 2>&1

	# Compression
	find $folder -ignore_readdir_race ! -name '*.bz2' -type f -mtime +$COMPRESS -exec bzip2 {} \;
done

# Client specific
compress_time=$(( $(date +%s) - $(($CLIENT_COMPRESS * 86400)) ))
delete_time=$(( $(date +%s) - $(($CLIENT_DELETE * 86400)) ))

for folder in $DIR/$CLIENT_FOLDER/*/ ; do
	[ "$(basename $folder)" = 'archives' ] && continue
	[ "$(basename $folder)" = 'spool' ] && continue

	folder_date=$(date -d $(basename $folder) +%s)

	if [ $folder_date -lt $delete_time ]; then
		rm -rf $folder
	elif [ $folder_date -le $compress_time ]; then

		for subfolder in $(find $folder/ -mindepth 1 -maxdepth 1 -type d) ; do
			foldername=$(basename $subfolder)
			
			tar cjf $folder/$foldername.tar.bz2 -C $folder $subfolder 2>/dev/null
			rm -rf $subfolder
		done
	fi
done
