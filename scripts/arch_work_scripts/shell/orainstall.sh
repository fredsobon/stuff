#!/bin/bash

# vim: set ft=shell
# vim: set ts=4 et sw=4

# Author: David Larquey <d.larquey@pixmania-group.com>

# ChangeLog
# 0.1   08/12       Initial build
# 0.2   08/12       Add oracle subdir access rights as requested by DBA
# 0.3   09/12       Oracle install directory is set to the full release name. Add a clone action before installing the patch
# 0.3b  2012/11/09  Minor changes: test the existence of the patch files


# ORA_INSTALL_BASEDIR must be a dedicated volume for oracle
# ORA_INSTALL_SOURCEDIR is the volume containing all install files (volume NFS), patchs and response files like:
# |-- install
# |   |-- cpu
# |   |   |-- 10.2
# |   |   `-- 11.2
# |   |-- distrib
# |   |   |-- 10.2.0.1
# |   |   |-- 11.2.0.3
# |   |   |-- EM
# |   |   `-- OPatch
# |   |-- patchset
# |   |   |-- 10.2.0.4
# |   |   `-- 10.2.0.5
# |   |-- rsp
# |   |   |-- oracle_ee_10gr2_linux_x86.rsp
# |   |   |-- oracle_ee_11gr2_linux_x86.rsp
# |   |   |-- p6810189_10204_Linux-x86-64.rsp
# |   |   |-- p8202632_10205_Linux-x86-64.rsp
# |   |-- scripts
# |   |   |-- orainstall.sh
# |-- oraInventory
# `-- product

export LANG=C

_TMP=/tmp/oraInstall
_TMPDIR=/tmp/oraInstall
LOCKFILE=/tmp/$(basename $0).lock
LOGFILE=/opt/oracle/$(basename $0).log

# Binaries
UNZIP=/usr/bin/unzip

# log files & checks
ORACLE_WAIT_TIMEOUT=600 # Time in seconds to install an oracle composent (distrib, patch)

# Directories
ORA_INSTALL_BASEDIR=/opt/oracle
ORA_INSTALL_SOURCEDIR=/opt/oracle/install
ORA_INSTALL_DESTDIR=/opt/oracle/product
ORA_INSTALL_DISTRIBDIR=$ORA_INSTALL_SOURCEDIR/distrib
ORA_INSTALL_PATCHDIR=$ORA_INSTALL_SOURCEDIR/patchset
ORA_RESPONSE_DIR=/opt/oracle/install/rsp
ORA_INSTALL_BASETMPDIR="/opt/oracle/SETUP.tmp"
ORA_INSTALL_LOGFILE=installActions

# Files
ORATAB_FILE=/etc/oratab

# Oracle
ORACLE_UID=oracle
ORACLE_GID=oinstall

# 10g
EOI_MESSAGE_10g="The installation of Oracle Database 10g was successful."

# 11g
EOI_MESSAGE_11g="The installation of Oracle Database 11g was successful."


declare -i APPLY_PATCH=0


#################
### Functions ###
#################

function LogError() {
    LogMessage "$@"
    exit 1
}

function LogMessage() {
    echo -e "[$(date)] $@" | tee -a $LOGFILE
}


function myexit() {
    local ret=$?
    [ -d $_TMPDIR ] && rm -rf $_TMPDIR
    LogMessage "Install Log file: $LOGFILE"
    [ -f /etc/redhat-release.ORI ] && cp -p /etc/redhat-release.ORI /etc/redhat-release
    [ $KEEP_TEMP_DIR -eq 0 ] && [ -n "$ORA_INSTALL_BASETMPDIR" ] && [ -d $ORA_INSTALL_BASETMPDIR ] && { LogMessage "Removing temp dir: $ORA_INSTALL_BASETMPDIR" ; rm -rf $ORA_INSTALL_BASETMPDIR; }

    msg="The installation of Oracle $ORA_DISTRIB"
    [ -n "$ORA_TARGET" ] && msg="${msg} Patch $ORA_TARGET"
    if [ $ret -eq 0 ]; then
        LogMessage " >>>>>>>>>>> ${msg} was successful <<<<<<<<<<<"
    else
        LogMessage "!!! ${msg} has failed !!!"
    fi
}

function PrintSyntax() {
cat <<EOH

$(basename $0) - Oracle Installer for e-merchant platforms"

SYNTAX
    $(basename $0) -d DISTRIB [-p PATH] [-h]"

    -l  Print available Distribs & Patchs
    -d  Specify the Oracle main distrib to install. It could be '10.2' or '11.2'
    -p  Specify the release patch to apply. Ex: 10.2.0.5"
    -k  Keep temp directory after install
    -h  Print help

EOH

}

function PrintRelease() {

    echo '+ Available Distribs:'
    find $ORA_INSTALL_DISTRIBDIR -mindepth 1 -maxdepth 1 -type d -name 1\* -exec basename {} \;

    echo '+ Available Patchs:'
    find $ORA_INSTALL_PATCHDIR -mindepth 1 -maxdepth 1 -type d -exec basename {} \;
}


function ask() {
        echo -e "$@ (y/n): "
        read
        [ -z "$REPLY" ] || [ "$REPLY" != 'y' ] && LogError "Abort."
}


# Fake Red hat release
function fake_release() {
    [ -f /etc/redhat-release.ORI ] || cp -p /etc/redhat-release /etc/redhat-release.ORI
    case "$ORA_DISTRIB" in
            10.2.0.1)
            echo "Enterprise Release Enterprise Linux server release 4" >/etc/redhat-release
        ;;
    esac
}

# $1=PATH
# $2=FILENAME
# $3=Message to intercept
wait_orainstall() {
    TIME=0
    local logfiles file
    echo -n "Waiting " >&2
    while true; do
        echo -n '.' >&2
        sleep 10; TIME=$((TIME+10))
        [ -n "$ORACLE_WAIT_TIMEOUT" -a $TIME -ge $ORACLE_WAIT_TIMEOUT ] && LogError "Timeout: Installation seems to have failed. PLEASE CHECK"
        for path in $1; do
            logfiles=$(find $path -name $2\*.log -mmin -1 2>/dev/null)
            for file in $logfiles; do
                tail -150 $file|grep -q -- "$3"
                [ ${PIPESTATUS[1]} -eq 0 ] && break 3
            done
        done
    done
    [ -n "$file" ] && LogMessage "Logfile: <$file>"
}


function exec_cmd_as_oracle() {
	[ -n "$CMD_RUNINSTALLER" ] || return
	LogMessage "Running command as oracle: $CMD_RUNINSTALLER"
	(
		su - oracle -c "export TMP=$_TMP ; export TMPDIR=$_TMPDIR ; $CMD_RUNINSTALLER" 2>&1 >/dev/null | tee -a $LOGFILE
	) &
}


function MakeResponseFile() {
    local reponseFile=$1
    [ -f $ORA_RESPONSE_DIR/$reponseFile ] || LogError "Can't find response file: $reponseFile"
    LogMessage "Making the response file: $reponseFile"
    cp -pf $ORA_RESPONSE_DIR/$reponseFile $ORA_INSTALL_TMPDIR/$reponseFile
}


function ExecRootPostInstallScript() {
    local script="$1" ret=0

    LogMessage "### Post-install scripts ###"
    LogMessage "Execution of post install script: ${ORA_INSTALL_BASEDIR}/oraInventory/$ORA_MAIN_DISTRIB/orainstRoot.sh"
    ${ORA_INSTALL_BASEDIR}/oraInventory/$ORA_MAIN_DISTRIB/orainstRoot.sh 2>&1 >/dev/null | tee -a $LOGFILE
        ret=$((ret|$?))
    LogMessage "Execution of post install script: ${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB/db_1/root.sh -silent"
    ${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB/db_1/root.sh -silent 2>&1 >/dev/null | tee -a $LOGFILE
        ret=$((ret|$?))
    [ $ret -eq 0 ] || LogError "An error occured while executing post install scripts (error=$ret)"
}


# ORA_INSTALL_TMPDIR must be set
function Install_Oracle() {

    local file CMD_RUNINSTALLER
    declare -i local ret=0
    ORA_INSTALL_TMP_LOGDIR=

    LogMessage ">>> Installation of Oracle distrib: $ORA_DISTRIB >>>"

    # Check if the distrib is already installed
    if [ -d $ORA_INSTALL_DESTDIR/$ORA_DISTRIB ]; then
        LogError "Oracle distrib $ORA_DISTRIB is already installed: ABORT. Please, clean the installation running this command as oracle user:\n\t$ORA_INSTALL_TMPDIR/database/runInstaller -responseFile $ORA_INSTALL_TMPDIR/$ORA_INSTALL_DB_RESPONSE_FILENAME -deinstall -removeallfiles"
    fi

    # Check if release (distrib + patch) is already installer
    if [ -d $ORA_INSTALL_DESTDIR/$ORA_TARGET ]; then
        LogError "Oracle target release (including patch) $ORA_TARGET is already installed: ABORT."
    fi

    ###
    # Unzip packages
    for file in ${ORA_INSTALL_SOURCE_FILES[@]}; do
        LogMessage "Unzipping package file $file to $ORA_INSTALL_TMPDIR"
        [ -f "$file" ] || LogError "Missing file: $file"
        local ext=${file##*.}
        case "$ext" in
            "zip")
                $UNZIP -d $ORA_INSTALL_TMPDIR $file 2>&1 >/dev/null | tee -a $LOGFILE
                [ $? -eq 0 ] || LogError "Can't unzip archive: $file. ABORT"
            ;;
            "cpio")
                OLDPWD=$(pwd)
                cd $ORA_INSTALL_TMPDIR && cpio -id <$file 2>&1 >/dev/null | tee -a $LOGFILE
                cd $OLDPWD >/dev/null
            ;;
        esac
    done

    ###
    # Making response file
    MakeResponseFile $ORA_INSTALL_DB_RESPONSE_FILENAME

    ###
    # Install oracle
    ORACLE_HOME=${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB/db_1
    LogMessage "Setting ORACLE_HOME=$ORACLE_HOME"

    local ora_distrib=$(echo $ORA_DISTRIB|tr . _)
    CMD_RUNINSTALLER="$ORA_INSTALL_TMPDIR/database/runInstaller -responseFile $ORA_INSTALL_TMPDIR/$ORA_INSTALL_DB_RESPONSE_FILENAME -silent -noconsole ORACLE_HOME=\"$ORACLE_HOME\" ORACLE_HOME_NAME=\"Db_${ora_distrib}_home\""

    LogMessage "+ Starting Oracle installer (Response file: $ORA_INSTALL_TMPDIR/$ORA_INSTALL_DB_RESPONSE_FILENAME)"
    exec_cmd_as_oracle

    return_status=${PIPESTATUS[0]}
    [ $return_status -ne 0 ] && LogError "Oracle installer can't be started. ABORT"

    sleep 1
    ORA_INSTALL_TMP_LOGDIR=$(find $_TMPDIR -maxdepth 1 -type d -mmin -1 -path $_TMPDIR/OraInstall\* 2>/dev/null)
    [ -n "$ORA_INSTALL_TMP_LOGDIR" ] && echo "Oracle temp directory: $ORA_INSTALL_TMP_LOGDIR"

    # Wait the end of the installation
    echo -e "\n[$(date)] Waiting for the Oracle installation to complete"
    wait_orainstall "${ORA_INSTALL_LOGDIR} ${ORA_INSTALL_TMP_LOGDIR}" installActions "$EOI_MESSAGE"
    echo
    LogMessage "Installation of Oracle release $ORA_DISTRIB is finished.\n"


    ### Post install ###
    ExecRootPostInstallScript "${ORA_INSTALL_BASEDIR}/oraInventory/$ORA_MAIN_DISTRIB/orainstRoot.sh"
    ExecRootPostInstallScript "${ORACLE_HOME}/root.sh -silent"
}


# ORA_INSTALL_TMPDIR must be set
function Install_Oracle_ApplyPatchs() {

    ###
    # Apply patchs
    ###

    ( [ $APPLY_PATCH -ne 1 ] || [ -z "$ORA_PATCH" ] || [ "$ORA_TARGET" == "$ORA_DISTRIB" ] ) && return
    [ -z "$EOI_MESSAGE_Patch1" ] && LogError "The message for the end of installation of the patch $ORA_PATCH is not set. Abort."

    LogMessage "### Patchs ###"
    ORACLE_HOME=${ORA_INSTALL_DESTDIR}/$ORA_TARGET/db_1
    LogMessage "+ Setting ORACLE_HOME=$ORACLE_HOME"
    sleep 10
    mkdir -p $ORA_INSTALL_TMPDIR/patchs/

# Desactivation kill listener
##    # Kill Listener
##    if pgrep tnslsnr; then
##        Ask "Listener is active. Kill it to continue"
##        pkill tnslsnr
##    fi

    local patch_name patch_ext
    file=$ORA_INSTALL_PATCH_FILES
    filename=$(basename $file)
    [ -z "$file" ] && break
    [ -f "$file" ] || LogError "Missing file: $file"
    patch_name=${filename%.*}
    patch_ext=${filename##*.}
    mkdir -p $ORA_INSTALL_TMPDIR/patchs/$patch_name

    if [ "$patch_ext" == "zip" ]; then
        LogMessage "Unzipping patch: $patch_name"
        $UNZIP -d $ORA_INSTALL_TMPDIR/patchs/$patch_name $file 2>&1 >/dev/null | tee -a $LOGFILE
        ret=$?
        [ $ret -eq 0 ] || LogError "Can't unzip patch file: $file. ABORT. (error=$ret)"
    fi
    [ -f $ORA_RESPONSE_DIR/${patch_name}.rsp ] || LogError "Missing patch response file: $ORA_RESPONSE_DIR/${patch_name}.rsp"
    MakeResponseFile ${patch_name}.rsp

    LogMessage "+ Making a copy of ${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB to ${ORA_INSTALL_DESTDIR}/$ORA_TARGET ..."
    rsync -a ${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB/ ${ORA_INSTALL_DESTDIR}/$ORA_TARGET 2>&1 >/dev/null | tee -a $LOGFILE

    LogMessage "+ Change the ORACLE_HOME from $ORA_DISTRIB to $ORA_TARGET into the oratab file"
    sed -i s@^oracle:/opt/oracle/product/$ORA_DISTRIB/db_1@oracle:/opt/oracle/product/$ORA_TARGET/db_1@ $ORATAB_FILE

    local ora_release=$(echo $ORA_TARGET|tr . _)
    CMD_RUNINSTALLER="$ORACLE_HOME/oui/bin/runInstaller -silent -noconsole -clone ORACLE_HOME=\"$ORACLE_HOME\" ORACLE_HOME_NAME=\"Db_${ora_release}_home\""

    local EOI_MESSAGE_Clone1="The cloning of Db_${ora_release}_home was successful"
    LogMessage "+ Clone the environment for applying patch: ${patch_name}"
    exec_cmd_as_oracle

    wait_orainstall "${ORA_INSTALL_LOGDIR} ${ORA_INSTALL_TMP_LOGDIR}" cloneActions "$EOI_MESSAGE_Clone1"

    LogMessage "+ Applying patch: ${patch_name}"
    CMD_RUNINSTALLER="$ORA_INSTALL_TMPDIR/patchs/$patch_name/Disk1/runInstaller -responseFile $ORA_INSTALL_TMPDIR/${patch_name}.rsp -silent -noconsole ORACLE_HOME=\"$ORACLE_HOME\" ORACLE_HOME_NAME=\"Db_${ora_release}_home\""
    exec_cmd_as_oracle

    wait_orainstall "${ORA_INSTALL_LOGDIR} ${ORA_INSTALL_TMP_LOGDIR}" installActions "$EOI_MESSAGE_Patch1"
    LogMessage "Installation of the patch ${patch_name} is finished\n"


    ### Post install ###
    ExecRootPostInstallScript "${ORA_INSTALL_DESTDIR}/$ORA_DISTRIB/db_1/root.sh -silent"

    LogMessage "+ Patch was applied succesfully\n"
    LogMessage "+ Relink all : running command as oracle user $ORACLE_HOME/bin/relink all"
        su - oracle -c "[ \"\$ORACLE_HOME\" == \"$ORACLE_HOME\" ] && { ${ORACLE_HOME}/bin/relink all; } || { echo 'ERROR: ORACLE_HOME at login of user oracle must be set to ${ORACLE_HOME}'; }" 2>&1 >/dev/null | tee -a $LOGFILE

    LogMessage "Applying access rights on $ORA_INSTALL_DESTDIR"
        su - oracle -c "chmod -R g+rwX $ORA_INSTALL_DESTDIR" 2>&1 >/dev/null | tee -a $LOGFILE
}




############
### MAIN ###
############

# ARGS
ORA_MAIN_DISTRIB=
ORA_DISTRIB=
ORA_PATCH=
KEEP_TEMP_DIR=0
LIST_RELEASE=0

while getopts 'hd:p:kl' option; do
    case "$option" in
        h) PrintSyntax; exit 0 ;;
        d) ORA_MAIN_DISTRIB=$OPTARG ;;
        p) APPLY_PATCH=1; ORA_PATCH=$OPTARG ;;
        k) KEEP_TEMP_DIR=1 ;;
    l) LIST_RELEASE=1 ;;
    esac
done
[ $LIST_RELEASE -eq 1 ] && { PrintRelease ; exit 0; }
[ -n "$ORA_MAIN_DISTRIB" ] || { PrintSyntax ; exit 1; }

[ -f /etc/redhat-release ] || LogError "This OS distribution is not compatible for the installation of oracle"
rpm -qa|egrep -q '^oracle-rdbms-server|^oracle-validated' || LogError "Missing the required package 'oracle-validated'"

LogMessage "########### Oracle install launcher started : $0 $@ ###########"
LogMessage "Install Log file: $LOGFILE"
[ "$(id -u)" == "0" ] || LogError "Only root can do that !"
[ -f $LOCKFILE ] && LogError "Lock file exists: can't run !"
[ -x $UNZIP ] || LogError "Missing binary: $UNZIP"

id -nG oracle|egrep '[[:blank:]]?oper[[:blank:]]?'|egrep -q "[[:blank:]]?${ORACLE_GID}[[:blank:]]?"|| LogError "Oracle must be member of groups: ${ORACLE_GID},oper"

[ -d $_TMPDIR ] && rm -rf $_TMPDIR;

trap myexit EXIT



### Distrib ###
case "$ORA_MAIN_DISTRIB" in
    10.2)
        ORA_DISTRIB=10.2.0.1 ;;
    11.2)
        ORA_DISTRIB=11.2.0.3 ;;
    *)
        LogError "The oracle main distribution should be: 10.2 or 11.2"
esac


# Check source files & release
[ "$(df -Ph $ORA_INSTALL_SOURCEDIR|tail -1|awk '{print $1}')" != "" ] || LogError "Volume oracle install is not mounted !"
[ -d $ORA_INSTALL_DISTRIBDIR/$ORA_DISTRIB ] || LogError "Missig oracle install directory: $ORA_DISTRIB !"
if [ -n "$ORA_PATCH" ]; then
    echo $ORA_PATCH|grep -q "^$ORA_MAIN_DISTRIB" || LogError "Can't apply patchset $ORA_PATCH who is not a patch of the distrib $ORA_MAIN_DISTRIB"
fi
[ -d $ORA_INSTALL_PATCHDIR/$ORA_PATCH ] || LogError "Missing patchset: $ORA_PATCH"


# Check destination
[ "$(df -Ph $ORA_INSTALL_BASEDIR|tail -1|awk '{print $1}')" != "" ] || LogError "Volume oracle base directory is not mounted !"
[ -d $ORA_INSTALL_DESTDIR ] || { mkdir -p $ORA_INSTALL_DESTDIR ; chown ${ORACLE_UID}:${ORACLE_GID} $ORA_INSTALL_DESTDIR; }

# Set TMP DIR for setup
ORA_INSTALL_TMPDIR="$ORA_INSTALL_BASETMPDIR/$ORA_DISTRIB"
[ -d $ORA_INSTALL_TMPDIR ] || mkdir -p $ORA_INSTALL_TMPDIR


### Patchs ###
ORA_INSTALL_PATCH_FILES=
EOI_MESSAGE_10g_Patch1=
EOI_MESSAGE_11g_Patch1=

# Set oracle target release (default is the distrib to install) and the patch to apply
ORA_TARGET=$ORA_DISTRIB
if [ "$ORA_MAIN_DISTRIB" == '10.2' ]; then
    case "$ORA_PATCH" in 
        10.2.0.4)
            ORA_TARGET=10.2.0.4
            ORA_INSTALL_PATCH_FILES=$ORA_INSTALL_PATCHDIR/$ORA_PATCH/p6810189_10204_Linux-x86-64.zip
            EOI_MESSAGE_10g_Patch1="The installation of Oracle Database 10g Release 2 Patch Set 3 was successful."
        ;;
        10.2.0.5)
            ORA_TARGET=10.2.0.5
            ORA_INSTALL_PATCH_FILES=$ORA_INSTALL_PATCHDIR/$ORA_PATCH/p8202632_10205_Linux-x86-64.zip
            EOI_MESSAGE_10g_Patch1="The installation of Oracle Database 10g Release 2 Patch Set 4 was successful."
        ;;
        *)
            if [ -n "$ORA_PATCH" ]; then
                LogError "This patch is not yet recognized. Please ask to your admin to implemente this"
            fi
        ;;
    esac
fi

[ -n "$ORA_INSTALL_PATCH_FILES" ] && [ ! -f "$ORA_INSTALL_PATCH_FILES" ] && LogError "Missing patchset file: $ORA_INSTALL_PATCH_FILES"

# Check oratab
[ -f $ORATAB_FILE ] || LogError "Missing oratab file: $ORATAB_FILE"
grep -q "^oracle:/opt/oracle/product/$ORA_DISTRIB/db_1" $ORATAB_FILE || LogError "Oracle distribution '$ORA_DISTRIB' for the user oracle is not or wrongly set into oratab file: $ORATAB_FILE. Abort."

fake_release
[ -f /etc/oraInst.loc ] && mv -f /etc/oraInst.loc /etc/oraInst.loc.OLD

ORA_INSTALL_LOGDIR=${ORA_INSTALL_BASEDIR}/oraInventory/$ORA_MAIN_DISTRIB/logs
LogMessage "Log directory: $ORA_INSTALL_LOGDIR"
mkdir -p ${ORA_INSTALL_LOGDIR} && chown -R ${ORACLE_UID}:${ORACLE_GID} ${ORA_INSTALL_BASEDIR}/oraInventory
sleep 2

ORA_INSTALL_SOURCE_FILES=
case "$ORA_DISTRIB" in
    "10.2.0.1")
        ORA_INSTALL_DB_RESPONSE_FILENAME=oracle_ee_10gr2_linux_x86.rsp
        ORA_INSTALL_SOURCE_FILES=($ORA_INSTALL_DISTRIBDIR/$ORA_DISTRIB/10201_database_linux_x86_64.cpio)
        EOI_MESSAGE=$EOI_MESSAGE_10g
        EOI_MESSAGE_Patch1=$EOI_MESSAGE_10g_Patch1
        Install_Oracle
        Install_Oracle_ApplyPatchs
    ;;
    "11.2.0.3")
        ORA_INSTALL_DB_RESPONSE_FILENAME=oracle_ee_11gr2_linux_x86.rsp
        ORA_INSTALL_SOURCE_FILES=($ORA_INSTALL_DISTRIBDIR/$ORA_DISTRIB/p10404530_112030_Linux-x86-64_1of7.zip $ORA_INSTALL_DISTRIBDIR/$ORA_DISTRIB/p10404530_112030_Linux-x86-64_2of7.zip)
        EOI_MESSAGE=$EOI_MESSAGE_11g
        EOI_MESSAGE_Patch1=$EOI_MESSAGE_11g_Patch1
        Install_Oracle
        Install_Oracle_ApplyPatchs
    ;;
    *)
        PrintSyntax; exit 1
    ;;
esac

