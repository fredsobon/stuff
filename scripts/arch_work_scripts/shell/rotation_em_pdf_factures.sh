#!/usr/bin/env bash
# $HeadURL: http://svn.e-merchant.net/svn/norel-puppet/modules/usrlocal/files/common/sys/tool/sbin/rotation_em_pdf_factures.sh $
# CNIL Compliance


DIR_INVOICES='/mnt/share/em_pdf_factures'
DIR_ARCHIVES='/mnt/share/arch_misc/em_pdf_factures_archives'


if [ ! -d "${DIR_INVOICES}" ]; then
  echo "Error: ${DIR_INVOICES} not found"
  exit 1
fi


_archive() {
  local period=$((365 * 5))

  cd ${DIR_INVOICES} || exit 1

  for client in $(ls); do
    [ ! -d ${client} ] && continue

    # Archive files
    rsync -av --relative --remove-source-files --files-from=<(find ${client} -mtime +${period} -type f) . ${DIR_ARCHIVES}/

    # Delete empty directories
    find ${client} -mindepth 1 -type d -empty -exec rmdir {} \; 2>/dev/null
  done
}


_purge() {
  local period=$((365 * 10))

  cd ${DIR_ARCHIVES} || exit 1

  for client in $(ls); do
    [ ! -d ${client} ] && continue

    # Purge archives
    find ${client} -mtime +${period} -type f -exec rm {} \;

    # Delete empty directories
    find ${client} -mindepth 1 -type d -empty -exec rmdir {} \; 2>/dev/null

  done
}


_archive
_purge

