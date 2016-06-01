#!/bin/bash

# vim: sw=4 et ts=4

# Author: dlarquey, <d.larquey@pixmania-group.com>
# Date: Thu Dec  6 16:13:49 CET 2012

# $Date$
# $URL$
# $Id$


# Revisions
# 2012-12-10	dlarquey	Add 'all' sort mode
# 2013-11-04	slienard	grep tuning, instant results


# Functions

myexit() {
    if [ $DELETE_TEMP_FILE == 1 ]; then
        for tempfile in ${TEMPFILES[@]}; do
            rm -vf $tempfile
        done
    fi
    find /tmp -name tmp.top10_?????? -mtime +1 -exec rm -f {} \; # delete old temp files if necessary
}

function syntax() {
cat <<EOF

    Usage: $(basename $0) <-m url|ip|backend|agent|referer|all> <-f FILE> [-l lines_to_go_back] [-F temp sort file] [-t]"

    Sort the most recurrent values in the specified accesslog file and it outputs the result either by url, IP, backend, user-agent, referer or all of these sort modes

    -m SORT MODE : url | ip | backend | agent | referer | all
        outputs the sorting result either by url, IP, backend (real servers), user-agent or referer
    -f FILE
        the accesslog FILE
    -F FILE
        use this temp FILE for sorting. (temp file was made by a previous treatment using the '-t' option). Be careful: don't forget to set the '-t' option for a later usage, otherwise the temp file will be deleted
    -l
        the number of lines to go back in the accesslog file. default is $DEFAULT_NR_LINES_TO_GO_BACK
    -t
        Don't delete temp file at exit: You can use it later with -F option.

EOF

exit

}

function create_temp_file() {
    if [ -n "$USE_SPECIFIC_TEMP_FILE" ] && [ -f $USE_SPECIFIC_TEMP_FILE ]; then
        tempfile=$USE_SPECIFIC_TEMP_FILE
        TEMPFILES[${#TEMPFILES[@]}]=$tempfile
        return
    fi
    tempfile=$(mktemp --tmpdir=/tmp tmp.top10_XXXXXX)
    TEMPFILES[${#TEMPFILES[@]}]=$tempfile
    echo "# Create temp log file with last <$LINES_TO_GO_BACK> lines: $tempfile"
    tail -n $LINES_TO_GO_BACK $FILE|grep -v varnish: >$tempfile
    local nr_lines=$(wc -l $tempfile|awk '{print $1}')
    echo -n "# First date in the log: "
    head -1 $tempfile|awk '{print $1}'
    echo "# Number of hits for real servers during this period: <$nr_lines>"
}

function top10_url() {
    create_temp_file
    grep "web[0-9].*HTTP/1\.1\" $RET_CODE" $tempfile|cut -d'[' -f2|awk '{print $3,$4}'|sort|uniq -c|sort -n
}

function top10_ip() {
    create_temp_file
    grep "web[0-9].*HTTP/1\.1\" $RET_CODE" $tempfile|cut -d'"' -f2|cut -d',' -f1|sort|uniq -c|sort -n
}

function top10_backend() {
    create_temp_file
    grep "web[0-9].*HTTP/1\.1\" $RET_CODE" $tempfile|awk '{print $2}'|sort|uniq -c|sort -n
}

function top10_referer() {
    create_temp_file
    grep "web[0-9].*HTTP/1\.1\" $RET_CODE" $tempfile|cut -d'"' -f6|sort|uniq -c|sort -n
}

function top10_useragent() {
    create_temp_file
    grep "web[0-9].*HTTP/1\.1\" $RET_CODE" $tempfile|cut -d'"' -f8|sort|uniq -c|sort -n
}


# MAIN

DEFAULT_NR_LINES_TO_GO_BACK=50000
typeset -a TEMPFILES

trap myexit EXIT
tempfile=
FILE=
LINES_TO_GO_BACK=${LINES_TO_GO_BACK:=$DEFAULT_NR_LINES_TO_GO_BACK}
DELETE_TEMP_FILE=1
USE_SPECIFIC_TEMP_FILE=
RET_CODE=
while getopts 'm:f:F:l:tc:' option; do
    case "$option" in
        f) FILE=$OPTARG ;;
        l) LINES_TO_GO_BACK=$OPTARG ;;
        m) MODE=$OPTARG ;;
        F) USE_SPECIFIC_TEMP_FILE=$OPTARG ;;
        t) DELETE_TEMP_FILE=0 ;;
        c) RET_CODE=$OPTARG ;;
    esac
done

[ -z "$FILE" ] && [ -z "$USE_SPECIFIC_TEMP_FILE" ] && syntax
[ -n "$USE_SPECIFIC_TEMP_FILE" ] && [ ! -f $USE_SPECIFIC_TEMP_FILE ] && { echo "Missing temp sort file: $USE_SPECIFIC_TEMP_FILE"; syntax; }
[ -n "$RET_CODE" ] && RET_CODE="${RET_CODE}0[0-9]"

case "$MODE" in
    url)
        top10_url
    ;;
    ip)
        top10_ip
    ;;
    backend)
        top10_backend
    ;;
    agent)
        top10_useragent
    ;;
    referer)
        top10_referer
    ;;
    all)
	NR_TOP_LINES=8
        if [ -z "$USE_SPECIFIC_TEMP_FILE" ]; then
            create_temp_file
            USE_SPECIFIC_TEMP_FILE=$tempfile
        fi
        echo "#### URLs ####"; top10_url | tail -n $NR_TOP_LINES
        echo "#### IPs ####"; top10_ip | tail -n $NR_TOP_LINES
	echo "#### Backends ####"; top10_backend | tail -n $NR_TOP_LINES
        echo "#### User-Agents ####"; top10_useragent | tail -n $NR_TOP_LINES
        echo "#### Referers ####";  top10_referer | tail -n $NR_TOP_LINES
    ;;
    *)
        syntax
    ;;
esac
