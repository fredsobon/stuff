#!/bin/bash
## prerequis: projet/share déjà existant
## Pour les insultes: f.dutheil@pixmania-group.com

# safety first
#set -e

#Global vars
DATA_COUNTER=0
SSH_CMD=`which ssh`
MAIN_CMD_BLK=""

usage()
{
	echo 
	echo "# Usage:"
	echo "`basename $0`[-u <USER>] [-f <FILER1_ADDR>] [-F <FILER2_ADDR>] < [-s] [-b] [-g] [-a] [-m] [-w] [-i] [-t] | [-A]>"
	echo
	echo "# Parameters description:"
	echo
	echo -e "\t-u <USER>: login onto <FILER_ADDR> using <USER> as SSH login name"
	echo
	echo "# Selection of LUNs settings to compare:"
	echo -e "\t-s: <LUN_SIZE>"
	echo -e "\t-b: <LUN_BLOCKSIZE>"
	echo -e "\t-g: <LUN_LOGBIAS>"
	echo -e "\t-a: <LUN_THIN>: thin provisioning"
	echo -e "\t-w: <LUN_WRITECACHE>"
	echo -e "\t-m: <LUN_COMPRESSION>"
	echo -e "\t-i: <INIT_GROUP>"
	echo -e "\t-t: <TARGET_GROUP>"
	echo -e "\t-A: All settings above (do not specify any of the previous ones then)"
	echo
	exit 1
}



get_lun_info()
{
    # $1: USER_NAME, $2: FILER_NAME
    
    FINAL_CMD_BLK=""
    OUTPUT=""
    LUN_LIST=""
    GLOBAL_LUN_LIST=""
    declare -a GLOBAL_LUN_ARRAY
    
    # Get projects'list
    #echo "INFO: getting projects list..."
    PROJECT_LIST=`$SSH_CMD -l $1 $2 shares list`

    # Generate final block of commands
    #echo "INFO: generating commands list..." 
    for PROJECT in $PROJECT_LIST
    do
        LUN_LIST=`$SSH_CMD -l $1 $2 shares select $PROJECT list|tail -n +5|cut -f 1 -d " "`
        GLOBAL_LUN_LIST="$GLOBAL_LUN_LIST
$LUN_LIST"
        for LUN in $LUN_LIST
        do
            FINAL_CMD_BLK="$FINAL_CMD_BLK
cd /
shares select $PROJECT select $LUN
$MAIN_CMD_BLK"
        
        done
    done
    
    # striping empty lines
    GLOBAL_LUN_LIST=`echo "$GLOBAL_LUN_LIST"| grep -v "^$"`
    GLOBAL_LUN_ARRAY=( $GLOBAL_LUN_LIST )
    FINAL_CMD_BLK=`echo "$FINAL_CMD_BLK"| grep -v "^$"`
    
    #echo "bloc de commandes:
#$FINAL_CMD_BLK"
    #echo "INFO: sending commands list to filer..." 
    DATA_RETURNED=`echo "$FINAL_CMD_BLK" | $SSH_CMD -l $1 $2`
    
    # Merging infos, format: "LUN_NAME: <data returned by filer>"
    #echo "INFO: formating results..." 
    GLOBAL_LUN_ARRAY_INDEX=0
    DATA_INDEX=1
    while read LINE
    do
	    OUTPUT="$OUTPUT
${GLOBAL_LUN_ARRAY[$GLOBAL_LUN_ARRAY_INDEX]}: $LINE"
	    
	    DATA_INDEX=`expr $DATA_INDEX + 1`
        if [ $DATA_INDEX -gt $DATA_COUNTER ]
        then
            # data of the next LUN are about to be processed
            DATA_INDEX=1
            GLOBAL_LUN_ARRAY_INDEX=`expr $GLOBAL_LUN_ARRAY_INDEX + 1`
        fi
    done < <( echo "$DATA_RETURNED" )
    
    # striping empty lines
    OUTPUT=`echo "$OUTPUT"| grep -v "^$"`
    
    echo "$OUTPUT"
}




# parsing command line options
while getopts "u:f:F:sbagmwitAh" optionname; do
case "$optionname" in
	u) USER_NAME="$OPTARG" ;;
	f) FILER1_NAME="$OPTARG" ;;
	F) FILER2_NAME="$OPTARG" ;;
	s) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get volsize";;
	b) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get volblocksize";;
	a) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get sparse";;	
	g) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get logbias";;
	m) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get compression";;
	w) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get writecache";;
	i) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get initiatorgroup";;
	t) DATA_COUNTER=`expr $DATA_COUNTER + 1` && MAIN_CMD_BLK="$MAIN_CMD_BLK
get targetgroup";;
    A)  if [ $DATA_COUNTER -ne 0 ]
        then 
            echo "ERROR: can't specify -A and any other LUN setting to be compared at the same time" 1>&2 && usage
        fi
        DATA_COUNTER=8 && MAIN_CMD_BLK="get volsize
get volblocksize
get sparse
get logbias
get compression
get writecache
get initiatorgroup
get targetgroup";;
	h) echo "" && usage ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done

# striping empty lines
MAIN_CMD_BLK=`echo "$MAIN_CMD_BLK"| grep -v "^$"`

# Misc Checks
if [ $DATA_COUNTER -eq 0 ]
then 
    echo "ERROR: no data selected for comparison" 1>&2 && usage
fi
if [ $DATA_COUNTER -gt 8 ]
then 
    echo "ERROR: can't specify -A and any other LUN setting to be compared at the same time" 1>&2 && usage
fi
if [ -z "$USER_NAME" ] ||  [ -z "$FILER1_NAME" ] ||  [ -z "$FILER2_NAME" ]
then
    echo "ERROR: missing parameter" 1>&2 && usage
fi

FILER1_DATAFILE=`mktemp`
FILER2_DATAFILE=`mktemp`
echo "INFO: Processing filer $FILER1_NAME..." 
get_lun_info $USER_NAME $FILER1_NAME|sort > $FILER1_DATAFILE
echo "INFO: Processing filer $FILER2_NAME..." 
get_lun_info $USER_NAME $FILER2_NAME|sort > $FILER2_DATAFILE

DIFF_RESULTS=`diff -y --suppress-common-lines $FILER1_DATAFILE $FILER2_DATAFILE`
if [ $? -ne 0 ]
then
    echo
    echo "Differences detected!"
    echo -e "$FILER1_NAME\t\t\t|\t $FILER2_NAME "
    echo
    echo "$DIFF_RESULTS"
fi
rm -f "$FILER1_DATAFILE" "$FILER2_DATAFILE"
