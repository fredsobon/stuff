#!/bin/bash

USER=$(echo $USER | sed 's/^\(.\)/\1./')
echo -n "Password: "
read -s PASS
echo
DSTDIR=~/Dropbox/Pix
FILENAME="e-merchant_SystemTeam-Planning_2014.xlsx"
FILE_ID="22158395"
FILE_TYPE="Zip archive data"
TMPDIR=/tmp
TMPFILE="$TMPDIR/$FILENAME"
DSTFILE="$DSTDIR/$FILENAME"

URL="http://wiki.e-merchant.net/dologin.action?os_username=$USER&os_password=$PASS&os_destination=/download/attachments/$FILE_ID/$FILENAME"

wget -q -O "$TMPFILE" "$URL"

if ( file "$TMPFILE" | grep -q "$FILE_TYPE" )
then

	diff -q "$TMPFILE" "$DSTFILE" >/dev/null

	if [ $? -ne 0 ]
	then
		cp "$TMPFILE" "$DSTFILE"
		echo "Updated."
	else
		echo "No change."
	fi
else
	echo "Bad file type." >&2
fi
rm -f "$TMPFILE"
