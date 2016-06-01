#!/bin/bash

MY_PATH="`dirname \"$0\"`"

MAIL_USERS="d.larquey@pixmania-group.com,n.germain@pixmania-group.com"

function send_mail() {
	object="$1"
	body="$2"
	echo -e "OBJECT: $object"
	echo -e "Body: $body"
	echo -e "$body" | mail -s "$object" $MAIL_USERS
}

echo "filer12.xxx"
ssh -Tl nagios filer12.storage.common.prod.std.e-merchant.net < /tmp/check_dif_luns | sort > /tmp/filer12std
ssh -Tl nagios filer12.storage.common.prod.vit.e-merchant.net < /tmp/check_dif_luns | sort > /tmp/filer12vit
diff=$(comm -3 /tmp/filer12vit /tmp/filer12std)
if [ -n "$diff" ]; then
	send_mail "[FILER12] Disk capacity gap between 2 sites" "\nfiler12vit\tfiler12std\n$diff"
fi


echo "filer13.xxx"
ssh -Tl nagios filer13.storage.common.prod.std.e-merchant.net < /tmp/check_dif_luns | sort > /tmp/filer13std
ssh -Tl nagios filer13.storage.common.prod.vit.e-merchant.net < /tmp/check_dif_luns | sort > /tmp/filer13vit
diff=$(comm -3 /tmp/filer13vit /tmp/filer13std)
if [ -n "$diff" ]; then
        send_mail "[FILER13] Disk capacity gap between 2 sites" "\nfiler13vit\tfiler13std\n$diff"
fi


rm -vf /tmp/filer12std /tmp/filer12vit /tmp/filer13std /tmp/filer13vit

