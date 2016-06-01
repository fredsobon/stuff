#!/bin/bash
## prerequis: projet/share déjà existant
## Pour les insultes: f.dutheil@pixmania-group.com

# safety first
set -e

#Global vars
OPER=""
OPER_COUNTER=0
LUN_OFFSET=0
SSH_CMD="`which ssh` -T"
MAIN_CMD_BLK=""
FINAL_CMD_BLK=""

usage()
{
	echo 
	echo "# Usage:"
	echo "`basename $0` [-c|-d|-r] [-u <USER>] [-f <FILER_ADDR>] [-p <PROJECT_NAME>] [-n <number_of_LUN>] [-o <LUN_OFFSET>] [-l <LUN_BASENAME>] [-s <LUN_SIZE>] [-b <LUN_BLOCKSIZE>] [-g <LUN_LOGBIAS>] [-a <LUN_THIN>] [-m <LUN_COMPRESSION>] [-w <LUN_WRITECACHE>] [-i <INIT_GROUP>] [-t <TARGET_GROUP>]"
	echo
	echo
	echo "# Operations description:"
	echo -e "\t-c: selects CREATE operation"
	echo -e "\t-d: selects DELETE operation"
	echo -e "\t-r: selects RECONFIGURE operation"
	echo
	echo
	echo "# Mandatory parameters description:"
	echo
	echo -e "\t-u <USER>: SSH login name" 
	echo -e "\t-f <FILER_ADDR>: FQDN or IP address" 
	echo -e "\t-p <PROJECT_NAME>: project/share name associated with LUNs to be processed" 
	echo -e "\t-n <number_of_LUN>: number of LUNs to be processed (i.e. created, deleted or reconfigured)"
	echo -e "\t-l <LUN_BASENAME>: final LUNs'names are built as this: <LUN_BASENAME>_1 to <LUN_BASENAME>_<number_of_LUN>. See <LUN_OFFSET> below if there are already existing LUNs with the same <LUN_BASENAME>." 
	echo -e "\t-s <LUN_SIZE>: with unit suffix: K, M, G or T"
    echo -e "\t-b <LUN_BLOCKSIZE>: with unit suffix: K"
	echo -e "\t-g <LUN_LOGBIAS>: value can be 'throughput' or 'latency' (without quotes)"
	echo -e "\t-i <INIT_GROUP>: initiator group"
	echo -e "\t-t <TARGET_GROUP>: target group"
	echo
	echo "# Optional parameters description:"
	echo -e "\t-o <LUN_OFFSET>: when creating LUNs with same <LUN_BASENAME> than already existing ones, set <LUN_OFFSET> to the number of already existing LUNs. Default: 0."
	echo -e "\t-a <LUN_THIN>: thin provisioning (called sparse option in CLI). Value can be 'true' or 'false' (without quotes). Default: false."
	echo -e "\t-w <LUN_WRITECACHE>: value can be 'true' or 'false' (without quotes). Only relevant in a RECONFIGURE operation. Default: false."
	echo -e "\t-m <LUN_COMPRESSION>: compression algorithm. Value can be 'gzip', 'gzip-2', 'gzip-9', 'lzjb' or 'off' (without quotes). Default: off."
	echo
	echo -e "\tNB: project <PROJECT_NAME>, target group <TARGET_GROUP> and initiator group <INIT_GROUP> must already exist before using this script."
	echo
	echo
	echo -e "# Example:"
	echo -e "\t./manage_LUNs.sh -c -u fdutheil -f filer12.storage.common.prod.std.e-merchant.net -n 1 -o 3 -p maa3_brainpix -l redo1_brainpix  -s 10G -b 128K -g latency -i igng_maa3 -t tgg_maa3"
	echo -e "\tThis command will create redo1_brainpix_4. You'll probably want to use the very same command again by only replacing '-f filer12.storage.common.prod.std.e-merchant.net' by '-f filer12.storage.common.prod.vit.e-merchant.net'."
	exit 1
}


# parsing command line options
while getopts "drcu:f:p:l:s:b:a:g:m:w:n:o:i:t:h" optionname; do
case "$optionname" in
	d) OPER="DELETE" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	r) OPER="RECONFIGURE" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	c) OPER="CREATE" && OPER_COUNTER=`expr $OPER_COUNTER + 1`;;
	u) USER_NAME="$OPTARG" ;;
	f) FILER_NAME="$OPTARG" ;;
	p) PROJECT_NAME="$OPTARG" ;;
	l) LUN_BASENAME="$OPTARG" ;;
	s) LUN_SIZE="$OPTARG" ;;
	b) LUN_BLOCKSIZE="$OPTARG" ;;
	a) LUN_THIN="$OPTARG" ;;	
	g) LUN_LOGBIAS="$OPTARG" ;;
	m) LUN_COMPRESSION="$OPTARG" ;;
	w) LUN_WRITECACHE="$OPTARG" ;;
	n) LUN_COUNT="$OPTARG" ;;
	o) LUN_OFFSET="$OPTARG" ;;
	i) INIT_GROUP="$OPTARG" ;;
	t) TARGET_GROUP="$OPTARG" ;;
	h) echo "" && usage ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done
# Misc Checks
if [ $OPER_COUNTER -eq 0 ]
then 
    echo "ERROR: no operation selected" 1>&2 && usage
fi
if [ $OPER_COUNTER -gt 1 ]
then 
    echo "ERROR: only one operation must be selected" 1>&2 && usage
fi
# TODO: verifier que LUN_COUNT est un entier

# Test if project exists
if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] ||  [ -z "$PROJECT_NAME" ]
then
    echo "ERROR: missing parameter" 1>&2 && usage
fi
if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME get creation | grep -q "not found"
then
    echo "ERROR: Share/Project $PROJECT_NAME does not exist." 1>&2 && usage
fi

# Generate main block of command
# + check if all parameters set
case x$OPER in
xDELETE)
    if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME select ${LUN_BASENAME}_`expr 1 + $LUN_OFFSET` get creation | grep -q "not found"
    then
        echo "ERROR: LUN ${LUN_BASENAME}_`expr 1 + $LUN_OFFSET` does not exist. You should use or fix the <LUN_OFFSET> value." 1>&2 && usage
    fi
;;
xRECONFIGURE)
    if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] ||  [ -z "$PROJECT_NAME" ] ||  [ -z "$LUN_BASENAME" ]||  [ -z "$LUN_COUNT" ]
    then
        echo "ERROR: missing parameter" 1>&2 && usage
    fi
    [ -n "$LUN_SIZE" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set volsize=$LUN_SIZE"
    [ -n "$LUN_LOGBIAS" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set logbias=$LUN_LOGBIAS"
    [ -n "$LUN_COMPRESSION" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set compression=$LUN_COMPRESSION"
    [ -n "$LUN_THIN" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set sparse=$LUN_THIN"
    [ -n "$LUN_WRITECACHE" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set writecache=$LUN_WRITECACHE"
    [ -n "$INIT_GROUP" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set initiatorgroup=$INIT_GROUP"
    [ -n "$TARGET_GROUP" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set targetgroup=$TARGET_GROUP"
    if [ -z "$MAIN_CMD_BLK" ]
    then
        echo "ERROR: no parameter set" 1>&2 && usage
    fi
    MAIN_CMD_BLK="$MAIN_CMD_BLK
commit"
;;
xCREATE)
   if [ -z "$USER_NAME" ] ||  [ -z "$FILER_NAME" ] ||  [ -z "$PROJECT_NAME" ] ||  [ -z "$LUN_BASENAME" ] ||  [ -z "$LUN_SIZE" ] ||  [ -z "$LUN_COUNT" ] ||  [ -z "$INIT_GROUP" ] ||  [ -z "$TARGET_GROUP" ]
    then
        echo "ERROR: missing parameter" 1>&2 && usage
    fi
    if $SSH_CMD -l $USER_NAME $FILER_NAME shares select $PROJECT_NAME select ${LUN_BASENAME}_`expr 1 + $LUN_OFFSET` get creation | grep -q "creation ="
    then
        echo "ERROR: LUN ${LUN_BASENAME}_`expr 1 + $LUN_OFFSET` already exists. You should use or fix the <LUN_OFFSET> value." 1>&2 && usage
    fi
    [ -n "$LUN_SIZE" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set volsize=$LUN_SIZE"
    [ -n "$LUN_BLOCKSIZE" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set volblocksize=$LUN_BLOCKSIZE"
    [ -n "$LUN_LOGBIAS" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set logbias=$LUN_LOGBIAS"
    [ -n "$LUN_COMPRESSION" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set compression=$LUN_COMPRESSION"
    [ -n "$LUN_THIN" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set sparse=$LUN_THIN"
    [ -n "$INIT_GROUP" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set initiatorgroup=$INIT_GROUP"
    [ -n "$TARGET_GROUP" ] && MAIN_CMD_BLK="$MAIN_CMD_BLK
set targetgroup=$TARGET_GROUP"
    if [ -z "$MAIN_CMD_BLK" ]
    then
        echo "ERROR: no parameter set" 1>&2 && usage
    fi
    MAIN_CMD_BLK="$MAIN_CMD_BLK
commit"
;;
*)
    echo "ERROR: operation not recognized" 1>&2 && usage
;;     
esac


# generate whole commands list
for COUNTER in `seq 1 $LUN_COUNT`
do    
    case x$OPER in
    xDELETE)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
confirm shares select $PROJECT_NAME select ${LUN_BASENAME}_`expr ${COUNTER} + $LUN_OFFSET` destroy"
    ;;
    xRECONFIGURE)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
shares select $PROJECT_NAME select ${LUN_BASENAME}_`expr ${COUNTER} + $LUN_OFFSET`
$MAIN_CMD_BLK"
    ;;
    xCREATE)
        FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
shares select $PROJECT_NAME lun ${LUN_BASENAME}_`expr ${COUNTER} + $LUN_OFFSET`
$MAIN_CMD_BLK"
    ;;
    *)
        echo "ERROR: operation not recognized" 1>&2 && usage
    ;;     
    esac
done

# send commands list to filer
# striping empty lines firts
FINAL_CMD_BLK=`echo "$FINAL_CMD_BLK"| grep -v "^$"`
# echo "$FINAL_CMD_BLK"
echo "$FINAL_CMD_BLK" | $SSH_CMD -l $USER_NAME $FILER_NAME
    

