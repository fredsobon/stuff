#!/bin/bash
## prerequis: projet/share déjà existant
## Pour les insultes: f.dutheil@pixmania-group.com

# safety first
set -e

## Global vars
OPER=""
OPER_COUNTER=0
SSH_CMD="`which ssh` -T"
FINAL_CMD_BLK=""

usage()
{
	echo 
	echo "Usage:"
	echo "`basename $0` [-c|-d|-r] [-u <USER>] [-f <FILER_ADDR>] [-n <number_of_LUN>] [-p <PROJECT_NAME>] [-l <LUN_BASENAME>] [-m <SNAPSHOT_NAME>]"
	echo
	echo "Operations description:"
	echo -e "\t-c: selects CREATE operation of snapshots"
	echo -e "\t-d: selects DELETE operation on snapshots"
	echo -e "\t-r: selects ROLLBACK operation on snapshots"
	echo "Parameters description:"
	echo -e "\t-u <USER>: login onto <FILER_ADDR> using <USER> as SSH login name" 
	echo -e "\t-l <LUN_BASENAME>: <number_of_LUN> LUNs are processed, with names build as this: <LUN_BASENAME>_1 to <LUN_BASENAME>_<number_of_LUN>" 
	echo
	exit 1
}


## parsing command line options
while getopts "dru:f:p:l:cm:n:h" optionname; do
case "$optionname" in
	d) OPER="DELETE" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	r) OPER="ROLLBACK" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	u) USER_NAME="$OPTARG" ;;
	f) FILER_NAME="$OPTARG" ;;
	p) PROJECT_NAME="$OPTARG" ;;
	l) LUN_BASENAME="$OPTARG" ;;
	c) OPER="TAKESNAP" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	m) SNAP_NAME="$OPTARG" ;;
	n) LUN_COUNT="$OPTARG" ;;
	h) echo "" && usage ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done


## Misc Checks

# all parameters set?
if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] ||  [ -z "$PROJECT_NAME" ] ||  [ -z "$LUN_BASENAME" ]|| [ -z "$SNAP_NAME" ]||  [ -z "$LUN_COUNT" ]
then
    echo "ERROR: missing parameter" 1>&2 && usage
fi
if [ $OPER_COUNTER -eq 0 ]
then 
    echo "ERROR: no operation selected (-d or -r or -s)" 1>&2 && usage
fi
if [ $OPER_COUNTER -gt 1 ]
then 
    echo "ERROR: only one operation must be selected (-d or -r or -s)" 1>&2 && usage
fi
# TODO: verifier que LUN_COUNT est un entier

# Test if project exists
if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME get creation | grep -q "not found"
then
    echo "ERROR: Share/Project $PROJECT_NAME does not exist." 1>&2 && usage
fi
    
# Various check based on wether snapshot already exists or not
case x$OPER in
xDELETE)
    if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME select ${LUN_BASENAME}_1 snapshots select $SNAP_NAME  get creation | grep -q "not found"
    then
        echo "ERROR: Snapshot $SNAP_NAME on LUN ${LUN_BASENAME}_1 does not exist." 1>&2 && usage
    fi
;;
xROLLBACK)
    if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME select ${LUN_BASENAME}_1 snapshots select $SNAP_NAME  get creation | grep -q "not found"
    then
        echo "ERROR: Snapshot $SNAP_NAME on LUN ${LUN_BASENAME}_1 does not exist." 1>&2 && usage
    fi
;;
xTAKESNAP)
    if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME select ${LUN_BASENAME}_1 snapshots select $SNAP_NAME get creation | grep -q "creation ="
    then
        echo "ERROR: Snapshot $SNAP_NAME on LUN ${LUN_BASENAME}_1 already exists." 1>&2 && usage
    fi
;;
*)
    echo "ERROR: operation not recognized" 1>&2 && usage
;;     
esac


## generate whole commands list
for COUNTER in `seq 1 $LUN_COUNT`
do    
    case x$OPER in
    xDELETE)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
confirm shares select $PROJECT_NAME select ${LUN_BASENAME}_${COUNTER} snapshots select $SNAP_NAME destroy"
    ;;
    xROLLBACK)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
confirm shares select $PROJECT_NAME select ${LUN_BASENAME}_${COUNTER} snapshots select $SNAP_NAME rollback"
    ;;
    xTAKESNAP)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
shares select $PROJECT_NAME select ${LUN_BASENAME}_${COUNTER} snapshots snapshot $SNAP_NAME"
    ;;
    *)
        echo "ERROR: operation not recognized" 1>&2 && usage
    ;;     
    esac
done

## send commands list to filer
# striping empty lines firts
FINAL_CMD_BLK=`echo "$FINAL_CMD_BLK"| grep -v "^$"`
#echo "$FINAL_CMD_BLK"
echo "$FINAL_CMD_BLK" | $SSH_CMD -l $USER_NAME $FILER_NAME
