#!/bin/bash

# vim: sw=4 et ts=4

# This script generate a cookie file, to use with a crawler
# You must specify an authentification URL and credentials for logon
# It stores the cookie in the file specified as argument

URL_AUTHENT=http://www.japan-diffusion.com/root/frfr/s_action/verif_authentification/index.html
AUTH_USER=0396001
AUTH_PWD=CAISSE
COOKIE_FILE=$1

[ -z "$COOKIE_FILE" ] && exit

echo "# Generate the AUTH cookie: <$COOKIE_FILE>"
curl  -D ${COOKIE_FILE}-tmp -d "login=$AUTH_USER&password=$AUTH_PWD" $URL_AUTHENT && cat ${COOKIE_FILE}-tmp|grep -i cookie|sed "s/Set-Cookie: //" >$COOKIE_FILE
rm -f ${COOKIE_FILE}-tmp
