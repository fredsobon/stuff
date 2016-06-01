#!/bin/bash

#
# E-Merchant: LDAP database dump script
#             by Vincent Batoufflet <vbatoufflet@e-merchant.com>
#

# Definitions
BACKUP_DIR=/srv/backup/ldap
BACKUP_MAX_AGE=15

# Create backup directory if missing
[ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR

# Get files suffix
DATE_SUFFIX=$(date +%Y%m%d_%H%M)

# Backup base configuration
tar -C /etc/ldap -c slapd.d | gzip -9 >$BACKUP_DIR/config-$DATE_SUFFIX.tar.gz

# Backup databases
IFS=$'\n'

for DB_NUM in $(
    ldapsearch -LLL -Y EXTERNAL -H ldapi:/// -b 'cn=config' '(objectClass=olcDatabaseConfig)' olcDatabase 2>/dev/null \
    | awk '$1 == "olcDatabase:" && $2 !~ /^\{(0|-1)\}/ {print gensub(/^\{([0-9]+)\}.*/, "\\1", "g", $2)}' \
); do
    FILE_PATH=$BACKUP_DIR/db$DB_NUM-$DATE_SUFFIX.ldif.gz

    # Generate dump file
    /usr/sbin/slapcat -n $DB_NUM | gzip -9 >$FILE_PATH

    # Rename file
    BASE_NAME=$(zcat $FILE_PATH | awk '$1 == "dn:" {gsub(/dc=/, "", $2); print $2}' | tr ',' '.' | head -1)
    mv $FILE_PATH ${FILE_PATH/\/db$DB_NUM-/\/$BASE_NAME-}
done

unset IFS

# Clean old databases dumps
[ -n "$BACKUP_DIR" ] && find $BACKUP_DIR -name '*.ldif.gz' -mtime +$BACKUP_MAX_AGE -delete

exit 0

# vim: ts=4 sw=4 et
