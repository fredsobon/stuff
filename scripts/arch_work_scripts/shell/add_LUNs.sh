#!/bin/bash
## Pour les insultes: f.dutheil@pixmania-group.com

# safety first
set -e

#Global vars
SSH_CMD="`which ssh` -T"
CONF_DIR="`dirname $0`/conf.d"
MULTIPATH_FILES_DIR="/tmp" # default value
MULTIPATH_HEADER="###################
# Alias multipath #
###################
# Add a multipath alias name for each LUN you add
multipaths {"
MULTIPATH_FOOTER="}"
ORACLE_UID=1002
ORACLE_GID=1000
TEST_MODE=false
DEBUG=false

usage()
{
	echo 
	echo "# Usage:"
	echo "`basename $0` [-d] [-t] -u <USER> -b <DATABASE_NAME> -l <LUN_TYPE> -n <number_of_LUN> [-f MULTIPATH_FILES_DIR ]"
	echo
	echo
	echo "# Parameters description:"
	echo
	echo -e "\t-u <USER>: SSH login name used to connect to filers (you'd better have your SSH public key deployed on them)"
	echo -e "\t-b <DATABASE_NAME>: valid names are: front, atools, btools, pplace, brainpix, order" 
	echo -e "\t-l <LUN_TYPE>: valid types are: data, index, lob, undo, temp, redo1, redo2, fra" 
	echo -e "\t-n <number_of_LUN>: number of LUNs to be processed (i.e. created, deleted or reconfigured)"
	echo -e "\t-f <MULTIPATH_FILES_DIR>: the tool will write the new multipath configuration files in this directory [default: /tmp]"
	echo -e "\t-t: Test mode (Show manage_LUNs.sh command but don't execute it)"
	echo -e "\t-d: Debug mode (Show some debug infos, implies -t)"
	echo
	echo
	exit 1
}


# parsing command line options
while getopts "u:b:n:l:f:h:dt" optionname; do
case "$optionname" in
	u) USER_NAME="$OPTARG" ;;
	b) DATABASE_NAME="$OPTARG" ;;
	d) DEBUG=true; TEST_MODE=true ;;
	n) LUN_COUNT="$OPTARG" ;;
	l) LUN_TYPE="$OPTARG" ;;
	f) MULTIPATH_FILES_DIR="$OPTARG" ;;
	h) echo "" && usage ;;
	t) TEST_MODE=true ;;
    *) echo "ERROR: unrecognized option $1" 1>&2; usage ;;
    esac
done

## Misc Checks
# TODO: verifier que LUN_COUNT est un entier
if [ -z "$USER_NAME" ] ||  [ -z "$DATABASE_NAME" ] ||  [ -z "$LUN_COUNT" ] || [ -z "$LUN_TYPE" ] 
then
    echo "ERROR: missing parameter" 1>&2 && usage
fi
if ! [ -d "$MULTIPATH_FILES_DIR" ]
then
    echo "ERROR: MULTIPATH_FILES_DIR is not a directory: $MULTIPATH_FILES_DIR" 1>&2 && usage
fi

if ! [ -w "$MULTIPATH_FILES_DIR" ]
then
    echo "ERROR: can't write in output directory MULTIPATH_FILES_DIR $MULTIPATH_FILES_DIR" 1>&2 && usage
fi

## Parse configuration files
if ! [ -r "$CONF_DIR/$DATABASE_NAME.conf" ]
then
    echo "ERROR: can't read configuration file $CONF_DIR/$DATABASE_NAME.conf" 1>&2 && usage
fi

MAA=`grep "^maa" "$CONF_DIR/$DATABASE_NAME.conf" | cut -f 2`

if ! [ -r "$CONF_DIR/$MAA.conf" ]
then
    echo "ERROR: can't read configuration file $CONF_DIR/$MAA.conf" 1>&2 && usage
fi

FILERS_LIST=`grep "^filers" "$CONF_DIR/$MAA.conf" |cut -f "2-"`
# we'll need one of them to send misc check commands, assuming all of them have the exact same storage configuration:
FIRST_FILER=`echo "$FILERS_LIST" | cut -f 1`

# get all DB associated with the same MAA cluster
DB_LIST_TEMP=`grep -l -e "^maa.${MAA}$" $CONF_DIR/*.conf | sort`
for DB in $DB_LIST_TEMP
do
    DATABASES_LIST="$DATABASES_LIST `basename ${DB%.conf}`"
done
	
PROJECT_NAME="${MAA}_${DATABASE_NAME}"

LUN_PARAMETERS=`grep "^$LUN_TYPE" "$CONF_DIR/$DATABASE_NAME.conf" | cut -f "2-"`
if [ -z "$LUN_PARAMETERS" ]
then
    echo "ERROR: no parameter found for LUN_TYPE $LUN_TYPE" 1>&2 && usage
fi
LUN_BASENAME=`echo "$LUN_PARAMETERS" | cut -f 6`
LUN_SIZE=`echo "$LUN_PARAMETERS" | cut -f 1`
LUN_BLOCKSIZE=`echo "$LUN_PARAMETERS" | cut -f 2`
LUN_THIN=`echo "$LUN_PARAMETERS" | cut -f 5`	
LUN_LOGBIAS=`echo "$LUN_PARAMETERS" | cut -f 3`
LUN_COMPRESSION=`echo "$LUN_PARAMETERS" | cut -f 4`
#LUN_WRITECACHE=
INIT_GROUP=`echo "$LUN_PARAMETERS" | cut -f 7`
TARGET_GROUP=`echo "$LUN_PARAMETERS" | cut -f 8`

# Test if project exists and if SSH connection is OK
if ! $SSH_CMD -l $USER_NAME $FIRST_FILER shares select $PROJECT_NAME get creation | grep -q "creation"
then
    echo "ERROR: Project $PROJECT_NAME does not exist or unable to connect to filer" 1>&2 && usage
fi	
# check already existing LUNs, and set LUN_OFFSET accordingly
LAST_LUN=`$SSH_CMD -l $USER_NAME $FIRST_FILER shares select $PROJECT_NAME list | grep "^$LUN_BASENAME" | cut -f 1 -d " " | sed "s/^${LUN_BASENAME}_//" | sort -n | tail -1`
if [ -z "$LAST_LUN" ]
then
    LUN_OFFSET=0
else
    LUN_OFFSET=`echo ${LAST_LUN#${LUN_BASENAME}_}`
fi


## create LUNs on all filers
for FILER in $FILERS_LIST
do
    echo "INFO: LUNs creation on $FILER..."
	if $TEST_MODE
	then
		echo `dirname $0`/manage_LUNs.sh -c -u $USER_NAME -f $FILER -p $PROJECT_NAME -n $LUN_COUNT -o $LUN_OFFSET -l $LUN_BASENAME -s $LUN_SIZE -b $LUN_BLOCKSIZE -g $LUN_LOGBIAS -a $LUN_THIN -m $LUN_COMPRESSION -i $INIT_GROUP -t $TARGET_GROUP
	else
		`dirname $0`/manage_LUNs.sh -c -u $USER_NAME -f $FILER -p $PROJECT_NAME -n $LUN_COUNT -o $LUN_OFFSET -l $LUN_BASENAME -s $LUN_SIZE -b $LUN_BLOCKSIZE -g $LUN_LOGBIAS -a $LUN_THIN -m $LUN_COMPRESSION -i $INIT_GROUP -t $TARGET_GROUP
	fi
done


## generate multipath configuration file

# build projects lists for which we'll write multipath configuration
PROJECTS_LIST=""
for DB in $DATABASES_LIST
do
    PROJECTS_LIST="$PROJECTS_LIST ${MAA}_${DB}"
done
# don't forget the cluster/grid dedicated projet
PROJECTS_LIST="$PROJECTS_LIST ${MAA}_cluster"

for FILER in $FILERS_LIST
do
    MULTIPATH_OUTPUT_FILE="$MULTIPATH_FILES_DIR/multipath-${MAA}-${FILER}.txt"
	> $MULTIPATH_OUTPUT_FILE
    
    echo "INFO: Building multipath configuration for $MAA on $FILER..."
    
    # add header
	echo "# Begin database $DATABASE_NAME (generated with \"`basename $0` $*\")" >> "$MULTIPATH_OUTPUT_FILE"
    echo "$MULTIPATH_HEADER" >> "$MULTIPATH_OUTPUT_FILE"

    for PROJECT in $PROJECTS_LIST
    do
		$DEBUG && echo "DEBUG:" `dirname $0`/gen_multipath_conf.sh -u $USER_NAME -f $FILER -p $PROJECT -U $ORACLE_UID -G $ORACLE_GID
        `dirname $0`/gen_multipath_conf.sh -u $USER_NAME -f $FILER -p $PROJECT -U $ORACLE_UID -G $ORACLE_GID >> "$MULTIPATH_OUTPUT_FILE"
    done
    
    # add footer
    echo "$MULTIPATH_FOOTER" >> "$MULTIPATH_OUTPUT_FILE"
	echo "# End database $DATABASE_NAME" >> "$MULTIPATH_OUTPUT_FILE"
    
    echo "INFO: File $MULTIPATH_OUTPUT_FILE created."
done
