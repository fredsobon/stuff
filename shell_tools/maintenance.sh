#!/bin/sh

usage() {
	echo "Usage: $(basename $0) none|full|external [instance]"
}

[ $# -lt 1 ] && { usage; exit 1; }
mode="$1"

echo "$mode" | grep -Eq '^(full|external|none)$' || { usage; exit 1; }

#instances='apc celio cfour monnier pixdeals pixmania pixpro bo'
instances='apc cfour pixdeals pixmania pixpro bo'
[ $# -eq 2 ] && instances="$2"

pool_cfour='rp01.front.cfour.prod.vit.e-merchant.net rp02.front.cfour.prod.vit.e-merchant.net rp03.front.cfour.prod.vit.e-merchant.net'
pool_pix='rp01.front.pix.prod.vit.e-merchant.net rp02.front.pix.prod.vit.e-merchant.net rp03.front.pix.prod.vit.e-merchant.net'
pool_bo='rp01.back.corepub.prod.vit.e-merchant.net rp02.back.corepub.prod.vit.e-merchant.net rp03.back.corepub.prod.vit.e-merchant.net'
pool_mutu='rp01.front.mutu.prod.vit.e-merchant.net rp02.front.mutu.prod.vit.e-merchant.net'

set_maintenance() {
#	$1 mode
#	$2 pool
#	$3 instance
	for host in $2; do
		ssh -l root $host "echo 'set req.http.X-Maintenance = \"$1\";' > /etc/varnish/$3/conf.d/maintenance.vcl ; service varnish restart $3 >/dev/null"
		RET=$?
		echo "Maintenance: $host - $instance - $1 - $([ $RET -eq 0 ] && echo 'OK' || echo 'KO')"
	done
}

for instance in	$instances ; do
	case $instance in
		apc|pixpro)
			set_maintenance "$mode" "$pool_mutu" "$instance"
		;;
		pixmania|pixdeals)
			set_maintenance "$mode" "$pool_pix" "$instance"
		;;
		cfour)
			set_maintenance "$mode" "$pool_cfour" "$instance"
		;;
		bo)
			set_maintenance "$mode" "$pool_bo" "$instance"
		;;
		*)
			echo "Unknown instance: $instance" >&2
		;;
	esac
done
