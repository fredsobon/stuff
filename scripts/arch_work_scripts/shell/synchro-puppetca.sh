#!/bin/sh
####################################
## THIS FILE IS MANAGED BY PUPPET ##
####################################
#
# File Name : synchro-puppetca.sh
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
# v.XX Last Modified : mar. 06 sept. 2011 14:45:39 CEST
#
USER='puppet'
HOST='master.puppet.common.prod.vit.e-merchant.net'
CADIR='/var/lib/puppet/ssl/'
OPTIONS='-avxH  --exclude "*.svn" -e ssh --delete'
PATH='/usr/bin'

echo "Importing certificats from ${HOST}:${CADIR}"
${PATH}/rsync ${OPTIONS} ${USER}@${HOST}:${CADIR} ${CADIR}
exit $?
