#!/usr/bin/env bash

# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/usrlocal/files/common/sys/tool/sbin/clean_ftp.sh $
# INFTSK-17016 : purge FTP e-merchant/em_crf_bi/Rapport\ assortiment/

LOGFILE='/var/log/purge_ftp.log'

_bi() {
  local directory='/mnt/share/dataexchange/data/e-merchant/em_crf_bi/Rapport assortiment/'
  local period=15

  find "${directory}" -type f -mtime +"${period}" -delete
}

_bi
