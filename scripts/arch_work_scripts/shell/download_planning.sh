#!/bin/bash

# Author: d.larquey

# This script donwloads the planning for your favorite team (default is DBA)
# In the aim of avoiding an http authentification, it uses the scp command from the wiki server to copy the XLS planning file
# The planningfile is stored in the local directory: $BASE_DATADIR/$TEAM . Default base directory is : DEFAULT_BASE_DATADIR
# To exploit the planning file, we convert the XLS file to the CSV format
# The converter tool used are : 'ssconvert' or 'xlsx2csv.py'

# Adapt the SSH and SCP commands for your needs

# Change logs:
# 16-06-2014    Add the management of a configuration file
# 29-04-2014    Fix bug to sort the planning file by the most recent date
# 18-04-2014    Initial build

# Depends: Gnumeric (ssconvert), xlsx2csv.py (https://github.com/dilshod/xlsx2csv.git), ssh/scp, sshpass (if necessary, for a password auth)



#######
# VAR #
#######

# Source to download the planning file
HOST=wiki.e-merchant.com
SOURCE_DATADIR_DBA=/opt/atlassian/confluence/data/attachments/ver003/148/162/8912898/95/32/
SOURCE_DATADIR_SYS=/opt/atlassian/confluence/data/attachments/ver003/39/24/524289/145/158/22158395/22547306/

# local destination
DEFAULT_BASE_DATADIR="$HOME/DATA/Planning"
MAX_RETENTION_DAYS=30

# Args
ARG_DEBUG=0
ARG_USE_SPECIFIC_CONVERTER=0

# CLI Commands & converter program
REMOTE_USER=root
SSH_COMMAND='ssh'
SCP_COMMAND='scp -p'

#~~~ Custom ~~~ #
#SSH_COMMAND='sshpass -p xxxxxxxxx ssh'
#SCP_COMMAND='sshpass -p xxxxxxxxx scp'

# Feel free to change the default converter program
ARG_CONVERT=1
ARG_CONVERTER_ID=0

# Post actions
#~~~ Custom ~~~ #
MY_REMOTE_DATADIR=
MY_REMOTE_SERVER=



#############
# Functions #
#############

#~~~ Custom ~~~ #
function post_download_actions_if_changes() {
    echo "+ [POST ACTION] Copy to my remote server : <${MY_REMOTE_SERVER}>"
    filename=${OUTPUT_FILE%.*}
    MY_REMOTE_DATADIR=$DATADIR
    # scp -i ... $DATADIR/${filename}.* ${MY_REMOTE_SERVER}:${MY_REMOTE_DATADIR}
}

function printSyntax() {
cat <<EOS

$(basename $0) - Download the Te@m planning
This script downloads the team planning from the server $HOST (using SCP)

    USAGE   $(basename $0) -t TEAM [-d] [-c]

        -c  FILE    Configuration file to use
                    Default is: \$HOME/.shift_planning
        -d  DATADIR Specify the base datadir containing data files
                    This parameter overrides those defined from the configuration file
        -t  TEAM    Your team for the planning. DBA (default) or SYS
                    This parameter overrides those defined from the configuration file
                    The DATADIR is the concatenation of the base directory and the name of the team
        -C 0,1      Try to convert the XLS file to CSV format using a converter too
                    
                0       ssconvert
                1       xlsx2csv.py
        -v          Turn on DEBUG/VERBOSE mode

EOS
}

function try_find_ssh_agent_sock() {
    local env_file=
    for proc in $(find /proc/ -maxdepth 2 -regextype posix-extended -regex "^/proc/[0-9]+/cmdline" -exec grep -al bash {} \;)
    do
        env_file="$(dirname $proc)/environ"
        sock_file=$(grep -a "USER=${USER}" $env_file 2>/dev/null|egrep -oia "SSH_AUTH_SOCK=[a-z0-9_./-]+"|cut -d'=' -f2)

        [ -n "$sock_file" ] && [ -S $sock_file ] && { echo $sock_file; echo "[try_find_ssh_agent_sock] PROC=$proc ; Find SSH AUTH SOCK: $sock_file" >&2; break; }
    done | head -n 1
}

function error() {
    echo -e "Error: $*" >&2
    exit 1
}

function debug() {
    [ $ARG_DEBUG -eq 1 ] || return
    echo $*
}

function load_config_file {
    [ -n "$ARG_CONFIG_FILE" ] || return
    [ -f $ARG_CONFIG_FILE ] || error "Can't find configuration file: $ARG_CONFIG_FILE"
    echo "[init] Reading configuration file: $ARG_CONFIG_FILE"
    team=$(awk -F'=' '/^team[ ]+/ {print $2}' $ARG_CONFIG_FILE|sed "s/ //g")
    datadir=$(awk -F'=' '/^datadir[ ]+/ {print $2}' $ARG_CONFIG_FILE|sed "s/ //g")

    [ -n "$datadir" -a -z "$ARG_BASE_DATADIR" ] && ARG_BASE_DATADIR=$datadir
    [ -n "$team" -a -z "$ARG_TEAM" ] && ARG_TEAM=$team
}


############
### MAIN ###
############

ARG_CONFIG_FILE=
ARG_BASE_DATADIR=
ARG_TEAM=

# Get options
while getopts c:d:t:C:hv option; do
    case "$option" in
        c) ARG_CONFIG_FILE=$OPTARG ;;
        d) ARG_BASE_DATADIR=$OPTARG ;;
        t) ARG_TEAM=$OPTARG ;;
        C) ARG_CONVERT=1 ; ARG_USE_SPECIFIC_CONVERTER=1; ARG_CONVERTER_ID=$OPTARG ;;
        v) ARG_DEBUG=1 ;;
        h) printSyntax; exit ;;
    esac
done



##########
### GO ###
##########

# INIT
[ -z "$ARG_CONFIG_FILE" ] && [ -f $HOME/.shift_planning ] && ARG_CONFIG_FILE=$HOME/.shift_planning

load_config_file
[ -z "$ARG_BASE_DATADIR" ] && { echo "Use the default base directory: $DEFAULT_BASE_DATADIR" ; ARG_BASE_DATADIR=$DEFAULT_BASE_DATADIR; }

# Dynamic VAR
MYTEAM=${ARG_TEAM:-DBA}
MYTEAM=${MYTEAM^^}
[ "$MYTEAM" == 'DBA' -o "$MYTEAM" == 'SYS' ] || error "The team must be 'DBA' or 'SYS'"
[ $ARG_USE_SPECIFIC_CONVERTER -eq 1 -a $ARG_CONVERT -eq 0 ] && error "You must enable the conversion before"
if [ $ARG_CONVERT -eq 1 ]; then
    case $ARG_CONVERTER_ID in
        0) BIN_CONVERT=ssconvert ;;
        1) BIN_CONVERT=xlsx2csv.py ;;
        *) BIN_CONVERT=ssconvert ;;
    esac
fi

# Set the local destination
DATADIR=${ARG_BASE_DATADIR}/${MYTEAM}
[ -d $DATADIR ] ||error "The directory does not exist: $DATADIR"
TEMP_OUTPUT_FILE=$(mktemp -t $(basename $0).XXX)
eval SOURCE_DATADIR=\${SOURCE_DATADIR_$MYTEAM}

# Find the most recent file on the local repository
echo "+ Use the planning file for the Team: ${MYTEAM}"
old_file=$(ls -1t ${DATADIR}/*.xls 2>/dev/null|head -n1)
mtime=$(stat -c %y $old_file 2>/dev/null|awk '{print $1,$2}')
if [ -n "$old_file" ] && [ -f "$old_file" ]; then
    old_md5=$(md5sum $old_file|awk '{print $1}')
    echo "+ Current most recent file: $old_file (Last modification time: <$mtime>)"
fi

# Prepare the download
# SSH Agent socket
SSH_AUTH_SOCK=$(try_find_ssh_agent_sock)
if [ -n "$SSH_AUTH_SOCK" ]; then
    echo "Exporting SSH auth socket: $SSH_AUTH_SOCK"
    export SSH_AUTH_SOCK
fi

# Download planning file
echo "+ Try to find the remote file (Host: $HOST)"
file_to_download=$(eval $SSH_COMMAND $REMOTE_USER@$HOST 'find ${SOURCE_DATADIR} -mtime -${MAX_RETENTION_DAYS} -type f -exec ls -l --time-style="+%s" {} \\\;| awk "{a=NF-1; print \$a,\$NF}"|sort -nr|head -1|awk "{print \$2}"')
[ -z "$file_to_download" ] && error "No planning file to download"
echo "OK, we found : ${HOST}:$file_to_download"

echo
echo "+ Downloading file <${HOST}:$file_to_download>"
eval $SCP_COMMAND -p $REMOTE_USER@$HOST:$file_to_download $TEMP_OUTPUT_FILE
ret=$?
([ $ret -ne 0 ] || [ ! -f $TEMP_OUTPUT_FILE ]) && error "Can't download the planning file from $REMOTE_USER@$HOST:$file_to_download"
new_md5=$(md5sum $TEMP_OUTPUT_FILE|awk '{print $1}')
debug "MD5: OLD output file:<$old_file> $old_md5"
debug "MD5: NEW output file:<$TEMP_OUTPUT_FILE> $new_md5"

# Any changes ?
echo
echo "+ Detect if changes has occured between old local and new downloaded file"
changes_detected=0

if [ "$old_md5" != "$new_md5" ]; then
    echo "=> Some changes were detected !!!"
    mtime=$(stat -c %y $TEMP_OUTPUT_FILE|awk '{print $1,$2}')
    OUTPUT_FILE=eMerchant_${MYTEAM}Team_Planning.$(date +%Y%m%d_%H:%M -d "$(stat -c %y $TEMP_OUTPUT_FILE|awk '{print $1,$2}')").xls
    mv -f $TEMP_OUTPUT_FILE $DATADIR/${OUTPUT_FILE}
    changes_detected=1
else
    echo "=> NO CHANGES were detected in the planning file"
    OUTPUT_FILE=$(basename $old_file)
fi
rm -f $TEMP_OUTPUT_FILE 2>/dev/null

echo "=> Most recent version of the planning file: $DATADIR/${OUTPUT_FILE}"
echo


# Purg old downloaded files
find $DATADIR -mtime +$MAX_RETENTION_DAYS -exec rm -vf {} \;

if [ $changes_detected -eq 1 ]; then
    if [ $ARG_CONVERT -eq 1 ]; then
        # Convert ths XLS file to CSV
        echo "+ Convert the XLS file to CSV (using $BIN_CONVERT)"
        ret=1
        if  [ -n "$BIN_CONVERT" ] && which $BIN_CONVERT >/dev/null 2>&1; then
            if test -f $DATADIR/${OUTPUT_FILE}; then
                filename=${OUTPUT_FILE%.*}
                if [ "$BIN_CONVERT" == 'ssconvert' ]; then
                    eval $BIN_CONVERT $DATADIR/${OUTPUT_FILE} $DATADIR/${filename}.csv >/dev/null 2>&1
                    ret=$?
                elif [ "$BIN_CONVERT" == 'xlsx2csv.py' ]; then
                    eval $BIN_CONVERT -a -f %Y/%m/%d $DATADIR/${OUTPUT_FILE} >$DATADIR/${filename}.csv 2>&1
                    ret=$?
                fi
            fi
            [ $ret -eq 0 ] || error "Can't convert to CSV"
            echo "Generated CSV file: $DATADIR/${filename}.csv"
            mtime=$(stat -c %y $DATADIR/${OUTPUT_FILE}|awk '{print $1,$2}')
            #echo "Change last modification time to: $mtime"
            #touch -d "$mtime" $DATADIR/${filename}.csv
        else
            error "$BIN_CONVERT is missing : can't convert to CSV"
        fi
    fi
    echo

    # post actions
    post_download_actions_if_changes

fi

