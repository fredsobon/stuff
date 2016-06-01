#!/bin/sh
####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################
# File Name : synchro-puppet.sh
# Creation Date : 06-09-2011
#
# For 
#
# This script ........................
# .....................................
# ...................................... 
#
# Author : Franck CAUVET <fcauvet@e-merchant.com> / f.cauvet@pixmania-group.com
#
# Copyright 2011  e-merchant/Pixmania
# All rights reserved.
#
# v.XX Last Modified : mar. 06 sept. 2011 14:46:13 CEST
#
USER='puppet'
HOST='master.puppet.common.prod.vit.e-merchant.net'
PUPPETDIR='/etc/puppet/'
OPTIONS='-avxH --exclude "*.svn" -e ssh --delete'
PATH='/usr/bin'

echo "Importing puppet files from ${HOST}:${PUPPETDIR}"
${PATH}/rsync ${OPTIONS} ${USER}@${HOST}:${PUPPETDIR} ${PUPPETDIR}
exit $?
