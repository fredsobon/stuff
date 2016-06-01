#!/usr/bin/env bash

DIRNAME=$(dirname $0)
NAME=$(basename $0)
SITES="vit dc3"
PUPPET_HOSTS="master.puppet.common.prod.vit.e-merchant.net slave01.puppet.common.prod.vit.e-merchant.net puppet01.cms.common.prod.dc3.e-merchant.net puppet401.cms.common.prod.dc3.e-merchant.net"
DRY_RUN="false"
URL_REPO_SVN="http://svn.e-merchant.net/svn/norel-tools"
REPO_SUBDIR="monit/misc/nagios-autoconf"
TMPDIR=${TMPDIR:-/tmp}
COLORS="true"



function error {
    echo "${RED}$*${END}" >&2
    exit 1
}


function usage() {
cat <<EOS
$(basename $0) - Generate the Nagios configuration for all supervisors

    -c  HOST  Clean the Host from Puppet
    -n        Dry run mode
    -h        This help
    -l        Synchronize your local copy of the 'tool' repository instead of the last release
              Force the Dry Run mode

EOS
exit 2

}


############
### MAIN ###
############

SYNC_LOCAL=0

([ -z "$DIRNAME" ] || [ "x$DIRNAME" == 'x/' ]) && error "Invalid base directory: $BASEDIR"

while getopts 'ng:c:hl' flag; do
  case "${flag}" in
    n) DRY_RUN='true' ;;
    c) clean="${OPTARG}" ;;
    h) usage ;;
    l) SYNC_LOCAL=1 ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done


if $COLORS
then
  RED=$(echo -e '\033[00;31m')
  GREEN=$(echo -e '\033[00;32m')
  YELLOW=$(echo -e '\033[00;33m')
  CYAN=$(echo -e '\033[00;36m')
  END=$(echo -e '\033[00m')
fi




# clean mode
if [ -n "$clean" ]; then
  for host in $PUPPET_HOSTS; do 
    ssh -l root $host "puppet cert clean $clean ; puppet node clean $clean"
  done
  exit
fi

if [ "$SYNC_LOCAL" -eq 0 ]; then
    status=$(svn status $DIRNAME|wc -l|awk '{print $1}')
    if [ $status -gt 0 ]; then
        echo "Some local changes are not commited into the directory: $DIRNAME"
        echo "All changes will be ignored."
        svn status $DIRNAME
        echo -n "Continue ? (y/N) "
        read answer
        [ "${answer,,}" != 'y' ] && exit 1
        echo
    fi

    # do the export
    EXPORTDIR=$(mktemp -d -p $TMPDIR $NAME.XXXX)
    [ -n "$EXPORTDIR" -a -d "$EXPORTDIR" ] || error "Can't create temp directory" >&2
    
    trap "[ -d $EXPORTDIR ] && rm -rf $EXPORTDIR" EXIT
    
    echo "Exporting $URL_REPO_SVN to $EXPORTDIR/export..."
    svn export $URL_REPO_SVN $EXPORTDIR/export >/dev/null
    if [ $? -ne 0 ]; then
        error "Can't export the repository"
    fi
    
    if [ ! -x "$EXPORTDIR/export/${REPO_SUBDIR}" ]; then
        error "Can't find directory: $EXPORTDIR/export/${REPO_SUBDIR}"
    fi

    LOCAL_DIR_TO_SYNC=$EXPORTDIR/export/${REPO_SUBDIR}/
    REMOTE_WORK_DIRECTORY_NAME="nagios-autoconf"
    REMOTE_WORK_DIRECTORY_BASE="/root"
    PURGE_REMOTE_DIRECTORY=0
else
    LOCAL_DIR_TO_SYNC=${DIRNAME}/
    REMOTE_WORK_DIRECTORY_BASE="/var/tmp"
    REMOTE_WORK_DIRECTORY_NAME="nagios-autoconf.$(date +%s)"
    PURGE_REMOTE_DIRECTORY=1
fi

REMOTE_WORK_DIRECTORY=${REMOTE_WORK_DIRECTORY_BASE}/${REMOTE_WORK_DIRECTORY_NAME}
REMOTE_WORK_SCRIPT="${REMOTE_WORK_DIRECTORY}/bin/remote_nagios-autoconf.sh"

[ -x $LOCAL_DIR_TO_SYNC ] || error "Can't find directory: $LOCAL_DIR_TO_SYNC"
#svn status $DIRNAME | while read mode file; do
#echo "$mode $file"
#done


# do the deployment to the supervisor
REMOTE_ARGS=
[ "$COLORS" == "true" ] && REMOTE_ARGS="${REMOTE_ARGS} -C"
[ $SYNC_LOCAL -eq 1 ] && REMOTE_ARGS="${REMOTE_ARGS} -n"
[ "$DRY_RUN" == 'true' ] && REMOTE_ARGS="${REMOTE_ARGS} -n"

for SITE in $SITES
do
  SERVER="master.monit.common.prod.${SITE}.e-merchant.net"
  echo -e "\n\n${GREEN}__________ ${SERVER}__________ :${END}"
  echo "Syncing ${LOCAL_DIR_TO_SYNC} to ${SERVER}:${REMOTE_WORK_DIRECTORY}"

  if [ $SYNC_LOCAL -eq 1 ]; then
    echo -e "${RED}/!\ Syncing from local uncommitted version => Dry run mode is forced !!!\n/!\ Ensure that your local repository is up to date${END}"
  fi

  rsync -rt --exclude .svn/ --delete ${LOCAL_DIR_TO_SYNC} root@${SERVER}:${REMOTE_WORK_DIRECTORY}/
  ret=$?
  [ $ret -eq 0 ] || error "Error during the synchronization to remote host"

  case "$SITE" in
        dc3) FINAL_SITE="dc3,asn,brn,bre";;
        vit) FINAL_SITE="vit";;
          *) FINAL_SITE="vit";;
  esac

  # execute remote script
  echo "${CYAN}Running remote script: ${REMOTE_WORK_SCRIPT}${END}"
  ssh root@$SERVER "[ -x $REMOTE_WORK_SCRIPT ] && $REMOTE_WORK_SCRIPT $REMOTE_ARGS -g $FINAL_SITE -d $REMOTE_WORK_DIRECTORY"
  ret=$?

  if [ $SYNC_LOCAL -eq 1 ] && [ $PURGE_REMOTE_DIRECTORY -eq 1 ] && echo $REMOTE_WORK_DIRECTORY|egrep -q '/var/tmp/nagios-autoconf.[0-9]+'; then
    echo "Purging remote directory: $REMOTE_WORK_DIRECTORY"
    ssh root@$SERVER "rm -rf $REMOTE_WORK_DIRECTORY"
  fi

done

# vim: set sw=2 et ts=2
