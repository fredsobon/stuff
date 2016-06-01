#!/bin/sh

STATIC_BASEPATH=/var/log/remote/prod/static/
TMPFILE=$(mktemp -p /var/log/tmp/mguillet)
FINALFILE=/var/log/tmp/mguillet/static.filelist.txt

rm -f "$FINALFILE"
for day in $(seq 0 -1 -3); do
	LOGDATE=$(date +%Y/%m/%d -d ${day}days)
	VARNISHLOG="$STATIC_BASEPATH/$LOGDATE/varnish.log"

	if [ -e "$VARNISHLOG.gz" ]; then
		VARNISHLOG="$VARNISHLOG.gz"
	elif ! [ -e "$VARNISHLOG" ]; then
		continue
	fi

	echo "Processing $VARNISHLOG..."
	zgrep -o '"GET .* HTTP/1.1" 200' $VARNISHLOG  | cut -d " " -f 2 | grep -v '\.cdn\.e-merchant\.com' >>$TMPFILE
done

echo "Ordering result..."
sort -u $TMPFILE >$FINALFILE
split -d -l 250000 $FINALFILE $FINALFILE
rm -f "$TMPFILE" "$FINALFILE"

echo "files list ready: $FINALFILE.<num>"
