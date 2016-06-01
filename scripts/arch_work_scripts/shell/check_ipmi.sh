#!/bin/sh

IPMITOOL='/usr/bin/ipmitool'
IPMIOPTS='-U root -P L4nPlu5+ -I lanplus'

HOST=$1

RET=1
if [ "$($IPMITOOL $IPMIOPTS -H ipmi.$HOST chassis power status 2>/dev/null)" = "Chassis Power is on" ]; then
    echo "OK"
    RET=0
else
    echo "WARNING: IPMI unreachable"
fi

exit $RET
