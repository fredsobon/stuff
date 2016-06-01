#!/bin/bash

# Synchronisation du confluence de STD vers celui de VIT

RSYNC='/usr/bin/rsync'
DIR_CONFLUENCE='/opt/atlassian/confluence/atlassian-confluence-4.3.2'
MODULE='confluence'
SPARE_CONFLUENCE='app02.tool.office.prod.dc3.e-merchant.net'
LOG_CONFLUENCE='/var/log/confluence_app_sync.log '
OPTIONS='-arvz --delete --exclude=logs/ --exclude=temp/'

${RSYNC} ${OPTIONS} ${DIR_CONFLUENCE} ${SPARE_CONFLUENCE}::${MODULE} > ${LOG_CONFLUENCE} 2>&1
