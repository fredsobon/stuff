#!/bin/bash

# vim: sw=4 et ts=4

# extractor
# This script extracts all http links in a file from a base url for a specified depth


# This script is used for japan-diffusion


URL=http://www.japan-diffusion.com/root/frfr/index.html
URL_BLACKLIST=http://www.japan-diffusion.com/root/frfr/s_action/unset/index.html
DEPTH_LEVEL=1
COOKIE_FILE=cookie-extractor
VERBOSE=0
LINKS_DIR=links
cnt=0


[ -d $LINKS_DIR ] ||  mkdir -p $LINKS_DIR

while true; do

    let cnt=cnt+1
    DATE=$(date +%F_%s)

    ./gen_cookie.sh $COOKIE_FILE

    if ([ -f $COOKIE_FILE ] && [ -s $COOKIE_FILE ]); then
        cat $COOKIE_FILE|awk '{print "> ",$0}'
        echo
        echo "[EXTRACTOR=$cnt] START Extractor: $(date)" >&2
        LINKS_FILE=$LINKS_DIR/Crawler_$DATE.links

        ./html_links_parser.pl --url $URL --depth $DEPTH_LEVEL --cookie-file $COOKIE_FILE --urls-blacklist $URL_BLACKLIST --verbose $VERBOSE|awk '{print $2}' >$LINKS_FILE

        if [ -f $LINKS_FILE -a -s $LINKS_FILE ]; then
            echo
            echo "# Purging old links file"
            find $LINKS_DIR -name \*.links -mmin +30 ! -name $(basename $LINKS_FILE) -exec rm -vf {} \;
        fi
        echo "[EXTRACTOR=$cnt] Job is DONE."
    fi

    sleep 600
done

