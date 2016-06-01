#!/bin/bash

####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################

# Author: <d.larquey@pixmania-group.com>
# Last modified: Fri Jan 25 15:39:05 CET 2013

#
# SCRIPT TO MONITOR SSL CERTIFICATE EXPIRY DATE
# This script checks the expiry date of all ssl certificates specified
# in the config file: check_ssl_certs.cfg

CHECK_MSG=
CHECK_MSG_OK=
CHECK_STATUS=0
DEBUG=0
SSL_EXPIRE_WARN_DAYS_DEFAULT=60 # default warning expiry date
SSL_EXPIRE_CRIT_DAYS_DEFAULT=30 # default critical expiry date
SSL_INPUT_FILE=//usr/local/nagios/etc/check_ssl_certs.cfg


# Control the sterr output
exec 6>&2
exec 2>&-

#################
### Functions ###
#################

# log
function log() {
    if [ $DEBUG -eq 1 ]; then 
        echo "[$(date)]$@"
    fi
    return 0
}

function logError() {
    exec 2>&6
    exec 6>&-
    log "$@" >&2
    exit 2;
}

function printSyntax() {
    cat <<EOF
$(basename $0) - Check SSL certificates listed in a config file
This script checks the expiry date of all certificates listed in the config file $SSL_INPUT_FILE

OPTIONS
    -w warning treshold in days before the certificate has expired
    -c critical treshold in days before the certificate has expired

EOF
}

# return status
check_aggr_return() {
    check_status=$1
    check_msg="$2"
    if [ ${check_status} -eq 0 ]; then
        [ -n "$CHECK_MSG_OK" ] && CHECK_MSG_OK="${CHECK_MSG_OK}\n${check_msg}" || CHECK_MSG_OK="${check_msg}"
    elif [ ${check_status} -ge $CHECK_STATUS ]; then
        [ -n "$CHECK_MSG" ] && CHECK_MSG="${check_msg}\n${CHECK_MSG}" || CHECK_MSG="${check_msg}"
        CHECK_STATUS=${check_status}
    else
        [ -n "$CHECK_MSG" ] && CHECK_MSG="${CHECK_MSG}\n${check_msg}" || CHECK_MSG="${check_msg}"
    fi
}

# sub checks
function check_resolv() {
    IP=$(host ${site} 2>/dev/null|tail -1|awk '{print $NF}')
    if [ -z "$IP" ]; then
        check_aggr_return 3 "Can't resolve $site"
        return 1
    fi
    log "[resolv] $site has IP: $IP"
}

function check_connect() {
    local ret

    nc -z ${site} $CHECK_PORT 2>/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
        check_aggr_return 3 "Can't connect to $site:$CHECK_PORT"
        log "ERROR: Can't connect to $site:$CHECK_PORT"
        return 1
    fi
    log "[connect] Successful connection on port $CHECK_PORT for $site"
    return 0
}

function get_ssl_cert() {
    local ret

    SSL_CERT_FILE=$(mktemp -t cert.$site.XXX)
    [ -z "$SSL_CERT_FILE" ] && { check_aggr_return 3 "Can't make temp file"; return 1; }
    (openssl s_client -connect ${site}:$CHECK_PORT -CApath /etc/ </dev/null 2>&1|awk '{if ($0 == "-----BEGIN CERTIFICATE-----") {go=1}; if (go == 1) {print $0}; if ($0 == "-----END CERTIFICATE-----") {go=0};}') >$SSL_CERT_FILE

    test -s $SSL_CERT_FILE
    ret=$?
    [ $ret -ne 0 ] && check_aggr_return 3 "Can't get SSL certificate for $site"
    log "[ssl] $site has a valid SSL certificate"
    return $ret
}


function check_cert() {
    [ -s $SSL_CERT_FILE ] || return 1
    local SSL_ENDDATE=$(openssl x509 -in $SSL_CERT_FILE -noout -enddate|sed "s/.*=//")
    [ -n "$SSL_ENDDATE" ] || { check_aggr_return 3 "Can't get certificate expiry date for $site"; return 1; }
    expiry_days=$((($(date -d "$SSL_ENDDATE" +%s) - $(date +%s))/86400))
    local tmp_site="$site"
    [ -n "$desc" ] && tmp_site="$tmp_site ($desc)"
    msg="SSL certificate for $tmp_site expires in $expiry_days days"

    if [ $expiry_days -le $SSL_EXPIRE_CRIT_DAYS ]; then
        check_aggr_return 2 "Critical: $msg (<=$SSL_EXPIRE_CRIT_DAYS)"
    elif [ $expiry_days -le $SSL_EXPIRE_WARN_DAYS ]; then
        check_aggr_return 1 "Warning: $msg (<=$SSL_EXPIRE_WARN_DAYS)"
    else
        check_aggr_return 0 "$msg"
    fi
    [ -f $SSL_CERT_FILE ] && rm -f $SSL_CERT_FILE 2>/dev/null
}

# main check
function do_check() {
    local site test desc
    site="$1"
    test="$2"
    desc="$3"

    SSL_CERT_FILE=
    CHECK_PORT=
    case "$test" in
        https) CHECK_PORT=443 ;;
        *) CHECK_PORT=80 ;;
    esac
    check_resolv $site && check_connect $site $test && [ $CHECK_PORT -eq 443 ] && get_ssl_cert $site && check_cert
}


function myexit() {
    if [ -n "$CHECK_MSG" ]; then
        echo -e $CHECK_MSG
    elif [ -n "$CHECK_MSG_OK" ]; then
        echo -e $CHECK_MSG_OK
    fi
}



############
### MAIN ###
############

trap myexit EXIT
SSL_EXPIRE_WARN_DAYS=$SSL_EXPIRE_WARN_DAYS_DEFAULT
SSL_EXPIRE_CRIT_DAYS=$SSL_EXPIRE_CRIT_DAYS_DEFAULT

while getopts w:c:h option; do
    case "$option" in
        w) SSL_EXPIRE_WARN_DAYS=$OPTARG ;;
        c) SSL_EXPIRE_CRIT_DAYS=$OPTARG ;;
        h) printSyntax; exit ;;
    esac
done

if [ -f $SSL_INPUT_FILE ]; then
    for line in $(cat $SSL_INPUT_FILE|egrep -v "^[[:blank:]]*$|^[[:blank:]]*#"|sed 's/[[:blank:]]*#.*//'); do
        site=$(echo $line|awk -F';' '{print $1}')
        test=$(echo $line|awk -F';' '{print $2}')
        desc=$(echo $line|awk -F';' '{print $3}')
        do_check $site $test "$desc"
    done
else
    check_aggr_return 1 "Missing config file: $SSL_INPUT_FILE"
fi

exit $CHECK_STATUS
