#!/bin/sh
# Author: Maxime Guillet
# Last Update: Mon, 01 Oct 2012 11:56:54 +0200

get_remote() {
	local_fqdn="$1"
	local_site="$(echo $local_fqdn | cut -d \. -f 5)"

	if [ "$local_site" = 'dc3' ]; then
		remote_site='vit'
	else
		remote_site='dc3'
	fi

	echo "$(echo $local_fqdn | cut -d \. -f 1-4).$remote_site.$(echo $local_fqdn | cut -d \. -f 6-)"

	return 
}

get_master() {
	host facette.e-merchant.net | tail -1 | awk '{print $1}' || exit 1
	return
}

FQDN=$(hostname -f) || { echo 'retrieving FQDN failed.' >&2; exit 1; }

[ "$(get_master)" != "$FQDN" ] && { echo 'Not the master.' >&2; exit 1; }

[ "$1" = '-n' ] && DRY_RUN='--dry-run --verbose'

rsync \
	--archive \
	--hard-links \
	--sparse \
	--delete \
	$DRY_RUN \
	/var/lib/facette/ \
	$(get_remote $FQDN)::facette/


