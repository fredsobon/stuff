#!/bin/sh

#set -x

# Version 0.0.2 2010-08-24
# Return 3 for unknown results.

# Version 0.0.1 2010-05-25
# Ulric Eriksson <ulric.eriksson@dgc.se>

BASEOID=.1.3.6.1.4
RSAOID=$BASEOID.1.2.3.51.1
tempOID=$RSAOID.2.20.1.1.1.1
voltOID=$RSAOID.2.20.2.1.1
fanOID=$RSAOID.2.3
healthStatOID=$RSAOID.2.7.1.0
# 255 = Normal, 0 = Critical, 2 = Non-critical Error, 4 = System-level Error

# 'label'=value[UOM];[warn];[crit];[min];[max]

usage()
{
	echo "Usage: $0 -H host -C community -T health|temperature|voltage|fans"
	exit 0
}

get_health()
{
	echo "$HEALTH"|grep "^$1."|head -1|sed -e 's,^.*: ,,'|tr -d '"'
}

if test "$1" = -h; then
	usage
fi

while getopts "H:C:T:" o; do
	case "$o" in
	H )
		HOST="$OPTARG"
		;;
	C )
		COMMUNITY="$OPTARG"
		;;
	T )
		TEST="$OPTARG"
		;;
	* )
		usage
		;;
	esac
done

RESULT=
STATUS=0	# OK

case "$TEST" in
health )
	HEALTH=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $healthStatOID`
	healthStat=`get_health $healthStatOID`
	case "$healthStat" in
	0 )
		RESULT="Health status: Critical"
		STATUS=2	# Critical
		;;
	2 )
		RESULT="Health status: Non-critical error"
		STATUS=1
		;;
	4 )
		RESULT="Health status: System level error"
		STATUS=2
		;;
	255 )
		RESULT="Health status: Normal"
		;;
	* )
		RESULT="Health status: Unknown"
		STATUS=3
		;;
	esac
	;;
temperature )
	TEMP=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $tempOID`

	# Figure out which temperature indexes we have
	temps=`echo "$TEMP" | grep -F "$tempOID.3." | grep -v "Not Readable" | cut -f 19 -d '.' | cut -f 1 -d ' '`

	if test -z "$temps"; then
		RESULT="No temperatures"
		STATUS=3
	fi
	for i in $temps; do
		tempName=`echo "$TEMP" | grep "$tempOID.2.$i " | cut -f 2- -d : | tr -d '"'`
		tempTemp=`echo "$TEMP" | grep "$tempOID.3.$i " | cut -f 2- -d : | tr -cd '0-9.'`
		tempCritical=`echo "$TEMP" | grep "$tempOID.4.$i " | cut -f 2- -d : | tr -cd '0-9.'`
		tempNoncritical=`echo "$TEMP" | grep "$tempOID.6.$i " | cut -f 2- -d : | tr -cd '0-9.'`
		RESULT="$RESULT$tempName = $tempTemp
"
		if test `expr "$tempTemp" ">=" "$tempCritical"` = 1; then
			STATUS=2
		elif test `expr "$tempTemp" ">=" "$tempNoncritical"` = 1; then
			STATUS=1
		fi
		PERFDATA="${PERFDATA}Temperature$i=$tempTemp;;;; "
	done
	;;
voltage )
	VOLT=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $voltOID`

	volts=`echo "$VOLT" | grep "$voltOID.3" | grep -v "Not Readable" | cut -f 18 -d '.' | cut -f 1 -d ' '`
	if test -z "$volts"; then
		RESULT="No voltages"
		STATUS=3
	fi
	for i in $volts; do
		voltName=Volt$i
		voltVolt=`echo "$VOLT" | grep "$voltOID.3.$i " | cut -f 2 -d : | tr -cd '0-9.'`
		voltCritHigh=`echo "$VOLT" | grep "$voltOID.5.$i " | cut -f 2 -d : | tr -cd '0-9.'`
		voltCritLow=`echo "$VOLT" | grep "$voltOID.9.$i " | cut -f 2 -d : | tr -cd '0-9.'`
		RESULT="$RESULT$voltName = $voltVolt (limits [$voltCritLow,$voltCritHigh])
"
		FAIL=`expr "(" "$voltCritLow" ">" 0 "&" "$voltVolt" "<=" "$voltCritLow" ")" "|" \
			"(" "$voltCritHigh" ">" 0 "&" "$voltVolt" ">=" "$voltCritHigh" ")"`

		if test "$FAIL" = 1; then
			STATUS=2
		fi
		PERFDATA="${PERFDATA}Voltage$i=$voltVolt;;;; "
	done
	;;
fans )
	FANS=`snmpwalk -v 1 -c $COMMUNITY -On $HOST $fanOID`

	fans=`echo "$FANS" | grep -v "Not Readable" | cut -f 14 -d .`
	if test -z "$fans"; then
		RESULT="No fans"
		STATUS=3
	fi
	for i in $fans; do
		fanName=Fan$i
		fanSpeed=`echo "$FANS" | grep $fanOID.$i.0 | cut -f 2 -d : | tr -cd '0-9%'`
		#fanSpeed=`echo "$FANS" | grep $fanOID.$i.0 | cut -f 2 -d : `
		RESULT="$RESULT$fanName = $fanSpeed
"
		PERFDATA="${PERFDATA}Fan$i=$fanSpeed;;;; "
	done
	;;
* )
	usage
	;;
esac

if [ -n "$PERFDATA" ]; then
	echo "$RESULT|$PERFDATA"
else
	echo "$RESULT"
fi

exit $STATUS
