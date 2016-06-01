#!/bin/sh

DIRNAME=$(dirname $0)

for site in dc3 vit; do
	( cd $DIRNAME;
	  scp -pr bin etc lib share poll01.monit.common.prod.$site.e-merchant.net:/var/www/collection
	)
done
