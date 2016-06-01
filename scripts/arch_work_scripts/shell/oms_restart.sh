#!/bin/sh

# script to restart OMS Grid control

OMS=/opt/oracle/middleware/oms11g/bin/emctl

error() {
    echo "ERROR:$*" >&1
    exit 1
}

start() {
echo
echo "[$(date)] Starting OMS"
$OMS start oms
ret=$?
echo "Return code: $ret"
}


stop() {
echo
echo "[$(date)] Stopping OMS"
echo
$OMS stop oms -force
ret=$?
sleep 1
echo "Return code: $ret"
echo

echo "Killing java"
pkill -u oracle -f java

}

[ -x $OPMS ] || error "Can't find OMS script: $OMS"
case "$1" in 
    start)
        start ;;
    stop)
        stop ;;
    restart)
        stop;
        start;
    ;;
    *)
        echo "Syntax: $0 [start|stop|restart]"
    ;;
esac

