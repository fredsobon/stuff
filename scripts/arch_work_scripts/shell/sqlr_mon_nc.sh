#!/bin/sh

if [ -z "$HM_SRV_IPADDR" ]
then
	HOST=$1
	PORT=$2
else
	HOST=$HM_SRV_IPADDR
	PORT=$HM_SRV_PORT
fi

EXPECTED=$(echo -e "\x00\x01\x00\x00")
RECEIVED=$(echo -e "\x00\x00\x00\x0bsupervision\x00\x00\x00\x08xiHoogu0" | nc $HOST $PORT)

if [ "$RECEIVED" = "$EXPECTED" ]
then
	exit 0
else
	exit -1
fi
