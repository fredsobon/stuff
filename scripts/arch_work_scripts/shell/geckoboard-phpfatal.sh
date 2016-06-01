#!/bin/bash

get_php_fatal() {
	PREFIX="/var/log/remote/prod/$1/"
	GECKO_W_ID="$2"
	TABLE1=''
	TABLE2=''

	MIN=-1
	MAX=0
	SWITCH=0

	for day in $(seq 15 -1 1); do
		past=$(echo "$(date +%s) - ($day*60*60*24)" | bc)
		date_folder=$(date +%Y/%m/%d -d@$past)
		date_axis=$(date +%m/%d -d@$past)

		if [ "$SWITCH" -eq 1 ]; then
			TABLE1="$TABLE1 $date_axis"
			SWITCH=0
		else
			TABLE1="$TABLE1 -"
			SWITCH=1
		fi

		value=$(zgrep -hc 'NOTICE: PHP message: PHP Fatal error' $PREFIX/$date_folder/php_fpm.log*)
		
		if [ "$value" -gt "$MAX" ]; then
			MAX=$value
		fi
		if [ "$MIN" -eq -1 ] || [ "$value" -lt "$MIN" ]; then
			MIN=$value
		fi

		TABLE2="$TABLE2 $value"
	done

	AXISX=$(echo $TABLE1 | sed -e 's/ /", "/g' -e 's/^/\["/' -e 's/$/"\]/')
	ITEM=$(echo $TABLE2 | sed -e 's/ /", "/g' -e 's/^/\["/' -e 's/$/"\]/')
	AVG=$(echo "($MAX+$MIN)/2" | bc )

	TMPFILE=$(mktemp)
	cat <<-EOF > $TMPFILE
	{
	  "api_key": "68407d43b2c331ccffae2fd83a05b255",
	  "data": {
	    "item": $ITEM,
	    "settings": {
	      "axisx": $AXISX,
	      "axisy": ["$MIN", "$AVG", "$MAX"],
	      "color": "#ff00aa"
	    }
	  }
	} 
	EOF

	REPLY=$(curl -s -x vip-proxy.secu.common.prod.vit.e-merchant.net:3128 \
		-X POST https://push.geckoboard.com/v1/send/$GECKO_W_ID -d @$TMPFILE)
	RETCODE=$?

	rm -f $TMPFILE

	if [ "$RETCODE" -eq 0 ] && echo "$REPLY" | grep -q 'success":true'; then
		return 0
	else
		return 1
	fi
}

get_php_fatal apc/fo 66353-faed8030-2211-0132-37af-22000b5e86d6
get_php_fatal carrefour/fo 66353-dc799610-2210-0132-e520-22000b490a2f
get_php_fatal celio/fo 66353-faed8030-2211-0132-37af-22000b5e86d6
get_php_fatal monnier/fo 66353-236e1650-2212-0132-e527-22000b490a2f
get_php_fatal pixdeals/fo 66353-c60d78a0-2212-0132-e528-22000b490a2f
get_php_fatal pixmania/fo 109043-0f57605a-1b97-4391-b481-9ef66e1e1536
get_php_fatal pixpro/fo 66353-ee194750-2210-0132-b5e9-22000b5391df

get_php_fatal brain/wsint 66353-9c1e9230-2213-0132-37b1-22000b5e86d6
get_php_fatal temp-wsint-client/wsint 66353-7aa2b7e0-2213-0132-6cb8-22000b51936c
get_php_fatal fraudbuster/wsint 66353-88f01d20-2213-0132-b5f7-22000b5391df

