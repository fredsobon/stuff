#!/bin/bash

# vim: ts=4 et sw=4

#
# E-merchant : this script aim to use html_links_parser.pl and use the output to catch state of html page : cached or not.
# http headers are retrieve and cache info catched to bring an csv output.  
# <j.duvoux@e-merchant.com> and color by Fsobon and remount,rw by dlarquey


date=$(date +%F_%s)
DATAFILE=/tmp/Crawler_$date.csv
LINKFILE=Crawler_$date.links
LOGFILE=/tmp/Crawler_$date.log


# Functions 

function print_usage() {
    cat <<EOF

Usage: $(basename $0) -u <url> -d <depth> [ -f INPUT_LINK_FILE] [ -H HOST_HEADER] [ -c COOKIE_FILE ] -s [SLEEP_TIME_BETWEEN_REQUESTS]

/!\CAUTION : You have to be in the html_links_parser.pl folder to use this script.

INPUT_LINK_FILE : this file contains all http links to crawl
If you don't specify an INPUT_LINK_FILE, then an extract will be done. In this case, you must specify a base URL and a DEPTH to extract all http links first.

[MODE EXTRACTOR]
    url: the origin url of the website you want to crawl
    depth: the depth you want to crawl the website : without this argument consider that you want to crawl the first level website. The depth's level is only : 0 to 6

[MODE WORKER]
    INPUT_LINK_FILE : This file contains all http links to crawl
    HOST_HEADER : "Host" header to send in http request
    COOKIE FILE: Specify the cookie file to send in all http requests


Example:
    crawler.sh -u http://foo.bar -d 1

EOF
    exit 1
}


function extract_links() {

    local OPTS
    ([ -n "$URL" ] && ([ -n $DEPTH ] && [ $DEPTH -ge 0 ] && [ ${DEPTH} -le 6 ])) || print_usage
    echo $URL | egrep -q '^https?:\/\/' || print_usage

    INPUT_LINK_LIST=$LINKFILE
    echo "# Generating input link file: $INPUT_LINK_LIST" >&2
    [ -n $HOST_HEADER ] && OPTS="$OPTS --host-header $HOST_HEADER"
    [ -n "$COOKIE_FILE" ] && [ -f $COOKIE_FILE ] && OPTS="$OPTS --cookie-file $COOKIE_FILE"

    ./html_links_parser.pl --url $URL --depth ${DEPTH} $OPTS|awk '{print $2}' 2>/dev/null >$INPUT_LINK_LIST
}


function crawl_links_list() {
    $CMD $INPUT_LINK_LIST | while read line
    do
        [ -z "$line" ] && continue
        if [ $(echo $line|grep -E "\.html?\??") ]; then
            echo -n "$line;"
            curl $OPTS -s -i -I -L ${line} |grep -E '(^X-Backend|^X-Cache|^X-RP|^Age|^HTTP|^Cache)'|sed -e ':a;N;$!ba;s/\r\n/;/g'
            [ -n "$SLEEP_TIME_BETWEEN_REQUESTS" ] && perl -MTime::HiRes -e "Time::HiRes::usleep 1000000*$SLEEP_TIME_BETWEEN_REQUESTS"
        else
            echo "Static content for this url: <$line>" >&2
        fi
    done
}



### MAIN ###


# Tests to be sure Arguments are correct : "$1" need an url - "$2" need to be : 0 1 or 2
declare -i DEPTH
HOST_HEADER=
COOKIE_FILE=
SLEEP_TIME_BETWEEN_REQUESTS=
while getopts 'hf:u:d:H:c:s:' option; do 
    case "$option" in 
        h) print_usage ;;
        u) URL=$OPTARG;;
        d) DEPTH=$OPTARG;;
        f) INPUT_LINK_LIST=$OPTARG;;
        H) HOST_HEADER=$OPTARG;;
        c) COOKIE_FILE=$OPTARG;;
        s) SLEEP_TIME_BETWEEN_REQUESTS=$OPTARG;;
    esac
done

if [ -z "$INPUT_LINK_LIST" ]; then
    extract_links
else
    [ -f $INPUT_LINK_LIST ] || { echo "Input link file doesn't exist : $INPUT_LINK_LIST"; exit 1; }
    echo "# Use input link file: <$INPUT_LINK_LIST>" >&2
fi


# Worker mode

declare -i r=$(($RANDOM%2))
CMD=cat
[ "x$r" == "x1" ] && CMD=tac
echo "# Command used for read: $CMD" >&2
OPTS=

if [ -n "$COOKIE_FILE" ] && [ -f $COOKIE_FILE ]; then
    echo "# Cookie file: $COOKIE_FILE" >&2
    COOKIE=$(cat $COOKIE_FILE)
    OPTS="$OPTS --cookie \"$COOKIE\""
fi

[ -n "$HOST_HEADER" ] && OPTS="$OPTS --header \"Host: $HOST_HEADER\""
echo "# OPTIONS=$OPTS" >&2

crawl_links_list

