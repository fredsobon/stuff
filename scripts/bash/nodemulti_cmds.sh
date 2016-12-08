#!/bin/bash
# Script to run a command across multiple machines
TIMEOUT=10
MACHINES=$1;shift
COMMAND=$1;shift

for machine in $MACHINES
do
echo $machine
ssh -oConnectTimeout=$TIMEOUT $machine $COMMAND

done
#Exemple :
#
#$ ./runremote.sh 'machine1 machine2 machine3 machine4' 'uptime'
#machine1
#13:15:59 up 8 days, 3:28, 1 user, load average: 0.00, 0.02, 0.00
#machine2
#13:10:03 up 153 days, 22:43, 0 users, load average: 0.50, 0.48, 0.45
#machine3
#13:16:00 up 117 days, 3:02, 9 users, load average: 0.39, 0.41, 0.45
#machine4
#13:16:00 up 99 days, 3:25, 2 users, load average: 3.55, 4.35, 4.31
