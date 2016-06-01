#!/bin/bash

# Synchronisation du confluence de STD vers celui de VIT

RSYNC='/usr/bin/rsync'
DIR_DATA_CONFLUENCE='/opt/atlassian/confluence/data'
MODULE='confluence'
SPARE_CONFLUENCE='app02.tool.office.prod.dc3.e-merchant.net'
LOG_DATA_CONFLUENCE='/var/log/confluence_data_sync.log '
OPTIONS='-arvz --delete --exclude=logs/ --exclude=temp/'

${RSYNC} ${OPTIONS} ${DIR_DATA_CONFLUENCE} ${SPARE_CONFLUENCE}::${MODULE} > ${LOG_DATA_CONFLUENCE} 2>&1
