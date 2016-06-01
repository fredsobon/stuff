#!/bin/bash

# vim: sw=4 et ts=4

# This script first extracts all prod numbered servers (member of a pool) from the DNS repository and create a DSH tree like:
#   ~/.dsh/group/PROD_dns2dsh/FUNCTION/SERVICE/PLATFORM/SITE/ALL
# 'ALL' file contains all hosts of the group
# Then, it browses the DSH tree step by step from the deepest sub directories to shallowest, making a concatenated hosts file for all sub directories, like:
# ~/.dsh/group/PROD_dns2dsh/FUNCTION/SERVICE/PLATFORM/SITE/all
# ~/.dsh/group/PROD_dns2dsh/FUNCTION/SERVICE/PLATFORM/all
# ~/.dsh/group/PROD_dns2dsh/FUNCTION/SERVICE/all
# ~/.dsh/group/PROD_dns2dsh/FUNCTION/all
# last, it creates all the cssh clusters by parsing all concatenated hosts file. the output is $CSSH_CLUSTER_CONFIG_FILE

# Dependencies:
# dns_search script used at E-Merchant for querying the DNS


###########
### VAR ###
###########

# Input & Output : To adapt depending on your configuration
#DNS_SCRIPT=$(which dns_search)          # DNS_SEARCH script is required !!!
DNS_SCRIPT=/home/boogie/repos/norel-dns/scripts/dns_search          # DNS_SEARCH script is required !!!
#DNS_SVN_PATH=/DATA/REMOTE/repository/dnszones/zones
DNS_SVN_PATH=/home/boogie/repos/norel-dns/zones/                           # your local DNS repository path
DSH_DIR=$HOME/.dsh/group/PROD_dns2dsh   # output of dns2dsh
CSSH_CONFIG_FILE=/home/boogie/.csshrc          # main cssh config file
#SVN_USER=dlarquey
SVN_USER=f.sobon

# Output
CSSH_CLUSTER_CONFIG_FILE=$HOME/.csshrc_clusters_dns2cssh_dns2cssh # Output of dsh2cssh : cssh cluster config file

# DNS repository
SVN_TRY_TO_EXPORT=yes                               # try to export the last revision of the DNS repository into a temporary directory. If it is not possible, then we use the local dns repository for querying DNS
SVN_TRY_TO_EXPORT_EXIT_ON_ERROR=no

SVN_HOST=svn.dns.common.prod.vit.e-merchant.net     # To fill if SVN_TRY_TO_EXPORT is set to 'yes'
SVN_REPO=dnszones

SITE=(std vit cha aga nan)
INITIAL_CONCATENATED_HOSTS_FILENAME=ALL
RECURSIVE_CONCATENATED_HOSTS_FILENAME=all

# Bin
SVN=/usr/bin/svn
CSSH=/usr/bin/cssh
REQUIRE_BIN=($SVN $DNS_SCRIPT $CSSH /bin/readlink)

# Misc
ARG_DEBUG=0



#################
### Functions ###
#################

function myExit {
    [ -n $TMP_DIR ] && [ -d $TMP_DIR ] && rm -rf $TMP_DIR 2>/dev/null
}

function logError {
    echo "ERROR: $@" >&2
    exit 1
}


function check_site {
    local found=1
    for site in ${SITE[@]}; do
        [ "$1" == "$site" ] && found=0 && break
    done
    return $found
}



function try_find_ssh_agent_sock() {
    local env_file=
    for proc in $(find /proc/ -maxdepth 2 -regextype posix-extended -regex "^/proc/[0-9]+/cmdline" -exec grep -al "/bin/bash" {} \;)
    do
        env_file="$(dirname $proc)/environ"
        sock_file=$(grep -a "USER=${USER}" $env_file|egrep -oia "SSH_AUTH_SOCK=[a-z0-9_./-]+"|cut -d'=' -f2)
        [ -n $sock_file -a -S $sock_file ] && echo $sock_file && break
    done | head -1
}


### dns2sh ###

# export the remote DNS repository at the last revision: always up to date
function dns2dsh_export_dns_svn_repository {
    echo "[dns2dsh] Exporting the remote DNS repository to $TMP_DIR <$SVN_USER@$SVN_HOST/$SVN_REPO> ..."
    #svn co svn+ssh://$SVN_USER@$SVN_HOST/$SVN_REPO $TMP_DIR 2>&1
    svn co --username f.sobon http://svn.e-merchant.net/svn/norel-dns $TMP_DIR 2>&1
    return $?
}


function dns2dsh_concatenate_hosts_file_from_dsh_dir() {
    local chrootdir="$1"
    local file
    echo -e "[dns2dsh] + Making the concatenated hosts file for <$chrootdir>"
    for file in $(find $chrootdir -type f -name $INITIAL_CONCATENATED_HOSTS_FILENAME)
    do
        echo -e "\tfrom: $file"
        # Create '$RECURSIVE_CONCATENATED_HOSTS_FILENAME' file by concatenating all subdirectories files
        cat $file >>$chrootdir/$RECURSIVE_CONCATENATED_HOSTS_FILENAME
    done
}


function dns2dsh_import_host_into_dsh_tree() {
    local host="$1"
    local host_is_valid=1
    tab=($(echo $host| tr '\.' ' '|sed s/e-merchant\..*//|sed s/fotovista\..*//))

    # filter on numered host
    echo ${tab[0]}|grep -q '[0-9]' || continue
    fonction=$(echo ${tab[0]}|sed "s/-\?[0-9]\+//g")
    tab[0]=$fonction
    tabn=${#tab[@]}
    
    echo "# Host: <$host>"
    
    dir=
    for i in $(seq 0 $(($tabn-1))); do
        [ $ARG_DEBUG -eq 1 ] && echo "- field: <${tab[$i]}>"
        # filter on only PROD environment
        [ "${tab[$i]}" == 'prod' ] && continue
        [ -n "$dir" ] && dir="${dir}/"
        dir="${dir}${tab[$i]}"
        check_site "${tab[$i]}" && host_is_valid=0 && break
    done
    [ -z "$dir" -o $host_is_valid -eq 1 ] && continue
    mkdir -p ${DSH_DIR}/$dir || logError "Can't create directory: ${DSH_DIR}/$dir"
    
    echo -e "\t-> [dns2dsh] Updating hosts file: ${DSH_DIR}/$dir/$INITIAL_CONCATENATED_HOSTS_FILENAME"
    echo $host >>${DSH_DIR}/$dir/$INITIAL_CONCATENATED_HOSTS_FILENAME
}



function make_dns2dsh() {

    [ -z "$SVN_USER" -a $SVN_TRY_TO_EXPORT == 'yes' ] && logError "Missing svn username. Can't export the DNS repository"
    # DNS svn repository
    [ -z "$DNS_SVN_PATH" -o ! -d "$DNS_SVN_PATH" ] && logError "Can't find a local DNS repository"

    do_export=0
    if [ $SVN_TRY_TO_EXPORT == 'yes' ]; then
        if [ -z "$SSH_AUTH_SOCK" ]; then
            echo "[dns2dsh] Try to find SSH auth socket"
            SSH_AUTH_SOCK=`try_find_ssh_agent_sock`
            if [ -z "$SSH_AUTH_SOCK" ]; then
                echo "Can't find the SSH auth socket !!!"
                [ $SVN_TRY_TO_EXPORT_EXIT_ON_ERROR == 'yes' ] && logError "Abort."
                echo " ---> Try to use the local DNS repository"
            else
                echo ">>> Found ssh auth socket: $SSH_AUTH_SOCK"
                export SSH_AUTH_SOCK
                do_export=1
            fi
        else
            do_export=1
        fi

        if [ $do_export -eq 1 ]; then
                dns2dsh_export_dns_svn_repository && echo "-> Exported."
                DNS_SVN_PATH=$TMP_DIR/zones
                [ -d $DNS_SVN_PATH ] || logError "[dns2dsh] Can't export the DNS repository: $DNS_SVN_PATH"
        fi
    fi
    export DNS_SVN_PATH
    
    # DSH tree
    echo "[dns2dsh] Local DNS repository: $DNS_SVN_PATH"
    echo "[dns2dsh] Purging DSH tree..."
    rm -rf $DSH_DIR/* >/dev/null 2>&1
    
    echo -e "\n### dns2dsh ###\n"

    echo "[dns2dsh] Creating DSH tree by querying the DNS repositories (PROD only) ..."
    for host in $($DNS_SCRIPT -g -1 '\.prod\.' -g|egrep -v 'preprod'|egrep -v '^ipmi|-vip|vip-|vip[0-9]|\*|\.dev\.|\.preprod\.')
    do
        dns2dsh_import_host_into_dsh_tree "$host"
    done

    echo "Purge all hosts file"
    find  $DSH_DIR -type f -name $RECURSIVE_CONCATENATED_HOSTS_FILENAME -exec rm -f {} \;

    echo -e "\n[$(date)] Create all concatenated hosts file by browsing subdirectories"
    for chrootdir in $(find $DSH_DIR -type d | while read line; do echo "${#line} $line"; done |sort -rn -k1 |awk '{print $2}')
    do
        # sort directories by length to first create the deepest concatenated hosts file, then down the directory tree step by step and concatenate all already concatenated files in subdirectories
        dns2dsh_concatenate_hosts_file_from_dsh_dir "$chrootdir"
    done

    # Deleting the deepest hosts file
    find $DSH_DIR -type f -name $INITIAL_CONCATENATED_HOSTS_FILENAME -exec rm -f {} \;
    
    echo "[$(date)] All PROD servers were exported on a DSH tree"
    return
}



### dsh2cssh ###

function dsh2cssh_write_cluster_list() {
    CLUSTER_LIST=$(echo $CLUSTER_LIST|sed 's/;//g')
    if [ -f $CSSH_CONFIG_FILE ]; then
        [ -f ${CSSH_CONFIG_FILE}.dns2cssh.ori ] || cp -f $CSSH_CONFIG_FILE ${CSSH_CONFIG_FILE}.dns2cssh.ori
    fi
    echo -e "\n### clusters ###\nclusters = $CLUSTER_LIST\n" >>$CSSH_CLUSTER_CONFIG_FILE
    local line="extra_cluster_file = $CSSH_CLUSTER_CONFIG_FILE"
    grep -q "^$line" $CSSH_CONFIG_FILE || echo "$line" >>$CSSH_CONFIG_FILE
}

function dsh2cssh_add_cluster() {
    local cluster_name="$1"
    local file="$2"
    echo $CLUSTER_LIST|grep -q " ${cluster_name};" && return 1
    echo -e "[dsh2cssh] Make cluster <${cluster_name}> from:\t\t$file"
    if ! egrep -q "^${cluster_name} =" $CSSH_CLUSTER_CONFIG_FILE ; then
        echo -e "# --- ${cluster_name} ---\n${cluster_name} = $(cat $file|xargs)\n" >>$CSSH_CLUSTER_CONFIG_FILE
        return 0
    fi
}


function make_dsh2cssh() {

    local i file
    local SITE_grep=
    local CLUSTER_LIST=

    echo -e "\n### dsh2cssh ###\n"
    [ -d $DSH_DIR ] || logError "Can't find DSH tree: $DSH_DIR"

    > $CSSH_CLUSTER_CONFIG_FILE
    for i in ${SITE[@]}; do SITE_grep="${SITE_grep}$i|"; done
    SITE_grep=${SITE_grep%*|}

    for file in $(find $DSH_DIR -type f -regextype posix-extended -regex ".*/($SITE_grep)/$RECURSIVE_CONCATENATED_HOSTS_FILENAME")
    do
        local cluster_name=$(echo ${file#*${DSH_DIR}/}|sed "s@/@_@g;s/_${RECURSIVE_CONCATENATED_HOSTS_FILENAME}$//")
        dsh2cssh_add_cluster "$cluster_name" "$file" && CLUSTER_LIST="$CLUSTER_LIST ${cluster_name};"

        dir=$(dirname $file)
        if [ -f $dir/../$RECURSIVE_CONCATENATED_HOSTS_FILENAME ]; then
            local subfile=$(readlink -e $dir/../$RECURSIVE_CONCATENATED_HOSTS_FILENAME)
            [ -f $subfile ] || continue
            [ $(md5sum $file|awk '{print $1}') != $(md5sum $subfile|awk '{print $1}') ] || continue
            cluster_name=$(echo ${subfile#*${DSH_DIR}/}|sed "s@/@_@g;s/_${RECURSIVE_CONCATENATED_HOSTS_FILENAME}$//")
            dsh2cssh_add_cluster "$cluster_name" "$subfile" && CLUSTER_LIST="$CLUSTER_LIST ${cluster_name};"
        fi
    done

    # make cssh cluster configuration
    [ -n "$CLUSTER_LIST" ] && dsh2cssh_write_cluster_list

    return
}




############
### MAIN ###
############

[ -z "$DNS_SCRIPT" -o ! -x "$DNS_SCRIPT" ] && logError "Missing DNS search script: $DNS_SCRIPT (PATH=$PATH)"
for bin in ${REQUIRE_BIN[@]}; do
    [ -x $bin ] || logError "Missing script or binary file: $bin"
done
if [ ! -f $CSSH_CONFIG_FILE ]; then
    echo "Initializing cssh config file: $CSSH_CONFIG_FILE"
#    $CSSH -u >$CSSH_CONFIG_FILE
fi

trap myExit 'EXIT'
TMP_DIR=$(mktemp -d)

[ -z $TMP_DIR ] && logError "Missing temp directory"

echo "[$(date)] dns2cssh: update cssh config file from DNS"
make_dns2dsh && make_dsh2cssh

echo "[$(date)] Cssh configuration is now up to date."
echo
echo "CSSH cluster list:"
grep "^clusters = " $CSSH_CLUSTER_CONFIG_FILE
echo

