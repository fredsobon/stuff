#!/bin/bash

#vars :
#cert_lists_path="/etc/ssl/certs"
cert_lists_path="certs"
renew_limit_day=30
alert_email_addr="bob@bob.com"
node=$(hostname)
sender="bob"
#to="bob.com"

#func :

help()
{
  echo "Usage: `basename $0` [-t <days>] [-m <dst_mailbox> ] "
  echo "  -t <days> Margin before certificate expiration in days.If not set 30 days are defined for test."
  echo "  -m <addr> To send email to specified address(es). If not set bob@bob.com is used."
  exit 1
}

while getopts "t:m: v h" OPT; do
    case $OPT in
        t) renew_limit_day="$OPTARG" ;;
        m) alert_email_addr="$OPTARG" ;;
        h) help ;;
        *) help ;;
    esac
done

# cleanup temporary files : 
echo " " > ${cert_lists_path}/main_certs_list
echo " " > ${cert_lists_path}/ko_certs_list

# List all certs present in the main directory and build a list used later to test.
cd ${cert_lists_path}
ls *.pem >> main_certs_list

## Main test : each cert retrieved from the main list is tested and expiration date compared to the renew limit date.
while read cert 
do
  checked_date=$(($(date +%s) + (86400*${renew_limit_day})))
  echo "== Check if "$cert" cert expires under "$renew_limit_day" days : ==" 
  expiration_date=$(date -d "$(openssl x509 -in "$cert" -text -noout \
          |grep 'Not After' \
          |awk '{print $4,$5,$7}')" '+%s')
  if [ "$checked_date" -gt "$expiration_date" ]
  then
    echo "Alert : expiration date for ssl cert. On ${node} the cert for "$cert" expires on $(date -d @$expiration_date '+%Y-%m-%d'). Less than $renew_limit_day days " >> ko_certs_list
  else 
    echo "OK - the cert for "$cert" expires on $(date -d @$expiration_date '+%Y-%m-%d')"      
  fi
done < main_certs_list

# Get ssl expiration cert alert 
[ -s ko_certs_list ] && 

( echo "From: ${sender}"
echo "To: ${alert_email_addr}"
echo "Subject: ssl certificate expiration"
echo 'MIME-Version: 1.0'
echo 'Content-Type: text/html'
echo 'Content-Disposition: inline'
echo " "
cat ko_certs_list ) | mail -s "Alerte ssl certificate expiration" ${alert_email_addr}

