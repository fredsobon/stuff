#!/bin/bash

# vim: sw=4 et ts=4

# Worker
# It takes as input file the list of URLs to crawl and generated by the extractor
# It crawls all html links of the list


# This script is used for japan-diffusion


URL=http://www.japan-diffusion.com/root/frfr/index.html
COOKIE_FILE=cookie-worker
LINKS_DIR=links
SLEEP_TIME_BETWEEN_REQUESTS=0.5
cnt=0


[ -d $LINKS_DIR ] || { echo "Missing directory: $LINKS_DIR"; exit 1; }

while true; do

    let cnt=cnt+1
    FILE=$(find $LINKS_DIR -name \*.links -mmin +1 -size +100c|sort|tail -1)

    if [ -n "$FILE" ] && [ -f $FILE ]; then
        echo "[WORKER=$cnt] START @ $(date)" >&2;
        ./gen_cookie.sh $COOKIE_FILE
        ./crawler.sh -f $FILE -c $COOKIE_FILE -s $SLEEP_TIME_BETWEEN_REQUESTS
        echo "[WORKER=$cnt] JOB is DONE"
    fi

    sleep 10
done
