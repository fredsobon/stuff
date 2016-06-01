#!/bin/bash

if [ -z "$HM_SRV_IPADDR" ]
then
	HOST=$1
	PORT=$2
else
	HOST=$HM_SRV_IPADDR
	PORT=$HM_SRV_PORT
fi

EXPECTED=$(echo -ne "\x00\x01\x00\x00")

# Open connection
exec 3<>/dev/tcp/$HOST/$PORT

if [ $? -ne 0 ]
then
	exit -1
fi

# Send
echo -ne "\x00\x00\x00\x0bsupervision\x00\x00\x00\x08xiHoogu0" >&3

# We can't use "read" because it doesn't handle "null string" (\x00)
RECEIVED=$(dd bs=1 count=4 <&3 2>/dev/null)

# Close connection
exec 3>&-
exec 3<&-

if [ "$RECEIVED" = "$EXPECTED" ]
then
	exit 0
else
	exit -1
fi
