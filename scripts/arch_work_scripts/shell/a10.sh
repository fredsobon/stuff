#!/bin/bash

if [ -z "$1" ]
then
	echo "Usage: $0 <USER> <HOST> <PARTITION> <COMMAND>" >&2
	exit 1
fi

USER=$1
HOST=$2
PARTITION=$3
COMMAND=$4

ssh -T $USER@$HOST <<END
active-partition $PARTITION
en

terminal length 0
$COMMAND
END
