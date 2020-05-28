#!/bin/bash
TARGET="mysite.example.net" 
#RECIPIENT="hostmaster@mysite.example.net"
DAYS=7


# check expiration date : convert in seconds then compare the result of the checked date ( date of the day + number of day defined for alerting ) : if the date of expiration is lower than the checked date : then the cert gonna expired : and trigger an alert .

echo "checking if $TARGET expires in less than $DAYS days";
expirationdate=$(date -d "$(: | openssl s_client -connect $TARGET:443 -servername $TARGET 2>/dev/null \
                              | openssl x509 -text \
                              | grep 'Not After' \
                              |awk '{print $4,$5,$7}')" '+%s') 
checked_date=$(($(date +%s) + (86400*$DAYS)))
if [ $checked_date -gt $expirationdate ]; then
    echo "KO - Certificate for $TARGET expires in less than $DAYS days, on $(date -d @$expirationdate '+%Y-%m-%d')" \
    #| mail -s "Certificate expiration warning for $TARGET" $RECIPIENT 
else
    echo "OK - Certificate expires on $expirationdate"
fi
