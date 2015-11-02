#!/bin/sh
# Script to retrieve pixmania billing before april 2008

PREFIX_PATH=/mnt/share/factures_pix
TOOL_SERVER=tool01.sys.common.prod.vit.e-merchant.net

if [ $# -ne 1 ]; then
	echo "Usage: $(basename $0) CCLID" >&2
	exit 1
fi

CCLID="$1"

FILE_PATHS=$(ssh root@$TOOL_SERVER "grep '^$CCLID' $PREFIX_PATH/facture_pdf.csv | awk -F ',' '{print \$2}'")

if [ -z "$FILE_PATHS" ]; then
	echo "Warning: can't find file for $CCLID!" >&2
	exit 1
fi

echo 'File path:'
echo "$FILE_PATHS"

scp $(for file in $FILE_PATHS; do echo -n "root@$TOOL_SERVER:$PREFIX_PATH/$file "; done) ./
