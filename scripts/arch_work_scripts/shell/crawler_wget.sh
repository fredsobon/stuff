#!/bin/bash

# vim: ft=sh ts=4 et sw=4

#
# E-merchant : this script aim to use html_links_parser.pl and use the output to catch state of html page : cached or not.
# http headers are retrieve and cache info catched to bring an csv output.  
# <j.duvoux@e-merchant.com> and color by Fsobon and remount,rw by dlarquey


#Functions 

print_usage() {
    cat <<EOF
Usage: $(basename $0) -u <url> -d <depth> [ -f INPUT_LINK_FILE] [ -H HOST_HEADER]

/!\CAUTION : You have to be in the html_links_parser.pl folder  to use this script.
this script should be use with two arguments :  
    - url : the origin url of the website you want to crawl : this is not an option .. 
    - depth : the depth you want to crawl the website : without this argument consider that you want to crawl the first level website.
The depth's level is only : 0 - 1 to 6
    - INPUT_LINK_FILE : Fichier de liens qui peut etre genere par ce script
    - HOST_HEADER : "Host" header to send in http request

EX :  crawler.sh -u http://foo.bar -d 1

EOF
    exit 1
}


# Tests to be sure Arguments are correct : "$1" need an url - "$2" need to be : 0 1 or 2
declare -i DEPTH
HOST_HEADER=
while getopts 'hf:u:d:H:' option; do 
    case "$option" in 
        h) print_usage ;;
        u) URL=$OPTARG;;
        d) DEPTH=$OPTARG;;
        f) inputlinkfile=$OPTARG;;
        H) HOST_HEADER=$OPTARG;;
    esac
done

([ -n "$URL" ] && ([ $DEPTH -ge 0 ] && [ ${DEPTH} -le 6 ])) || print_usage
echo $URL | egrep -q '^https?:\/\/' || print_usage

date=$(date +%F_%s)

DATAFILE=/tmp/Crawler_$date.csv
LINKFILE=Crawler_$date.links
LOGFILE=/tmp/Crawler_$date.log

if [ -z "$inputlinkfile" ]; then
    inputlinkfile=$LINKFILE
    echo "Generating input link file: $inputlinkfile" >&2
    if [ -n $HOST_HEADER ]; then
        ./html_links_parser.pl --url $URL --depth ${DEPTH} --host-header $HOST_HEADER|awk '{print $2}' 2>/dev/null >$inputlinkfile
    else
        ./html_links_parser.pl --url $URL --depth ${DEPTH} |awk '{print $2}' 2>/dev/null >$inputlinkfile
    fi
else
    [ -f $inputlinkfile ] || { echo "Input link file doesn't exist : $inputlinkfile"; exit 1; }
    echo "Use input link file: $inputlinkfile" >&2
fi

#exec 3<$inputlinkfile
declare -i r=$(($RANDOM%2))
CMD=cat
[ "x$r" == "x1" ] && CMD=tac
echo "Command used for read: $CMD" >&2

$CMD $inputlinkfile|
while read line
do
    if [ $(echo $line|grep -E "\.html?\??") ]; then
        echo -n "$line;"
        if [ -n $HOST_HEADER ]; then
#            curl --header "Host: $HOST_HEADER" -s -i -I -L ${line} |grep -E '(^X-Backend|^X-Cache|^X-RP|^Age|^HTTP)'|sed -e ':a;N;$!ba;s/\r\n/;/g' # | tee -a $DATAFILE
            wget --delete-after -nd --header="Host: $HOST_HEADER" -S -r -l 3 -D celio.fo.e-merchant.com --progress=dot --timeout=1 --tries=2 --no-verbose --no-check-certificate ${line} |awk '/^2012/ {f="";head=$2";"$3; getline; while ($0~/^ /) {if ($1~/HTTP|X-Cache|X-RP|X-Backend|Cache-Control|Age/) {f=f" "$1" "$2";";}; getline;}; print head,f}'

        else
#            curl -s -i -I -L ${line} |grep -E '(^X-Backend|^X-Cache|^X-RP|^Age|^HTTP)'|sed -e ':a;N;$!ba;s/\r\n/;/g' # | tee -a $DATAFILE
            wget --delete-after -nd -S -r -l 3 -D celio.fo.e-merchant.com --progress=dot --timeout=1 --tries=2 --no-verbose --no-check-certificate ${line} |awk '/^2012/ {f="";head=$2";"$3; getline; while ($0~/^ /) {if ($1~/HTTP|X-Cache|X-RP|X-Backend|Cache-Control|Age/) {f=f" "$1" "$2";";}; getline;}; print head,f}'
        fi
    else 
        echo "Static content for this url : $line"  # >> $LOGFILE
    fi
done #<&3
#exec 3<&-

