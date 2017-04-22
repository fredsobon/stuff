#!/bin/bash

#dbg=echo
host=$1
repodir="/mcorp/data/repository"
prod_rsynccachedir=".rsync_cache"
uat_rsynccachedir=".rsync_cache_uat"
capistranodir="/mcorp/apps/capistrano-lapin"
all_microservices="$(/bin/ls -1d /mcorp/data/repository/private-api-*-built.git | sed -e 's/.*private-api-//g' -e 's/-built.git//g')"
exclude="bench"

#controle de parametre


#recuperation des produits à deployer sur la machine
products=$(egrep "^[^#]*${host}" ${capistranodir}/*/{uat,prod}.rb | egrep -v "${exclude}" | sed "s#${capistranodir}/\(.*\)/\(.*\).rb:.*#\1#")
#recuperation d'environnement de la machine (1 seul)
platform=$(grep $host ${capistranodir}/*/{uat,prod}.rb | sed "s#${capistranodir}/\(.*\)/\(.*\).rb:.*#\2#" | tail -1 )

#pour chaque produit de la machine
for product in $products ;do  

	# microservices
	if [ x"${product}" = x"private-api" ]
	then
		for msdir in $(/bin/ls -1ad /mcorp/data/repository/private-api-* | grep -v built.git)
		do
			cd ${msdir}
			msname=$(basename ${msdir} | sed -e 's/.*private-api-//g')
			revision=$(eval cat \$${platform}_rsynccachedir/revision)
			[ "x$revision" = "x" ] && echo "failed to get las revision for microservice ${msname}" >&2 && continue
			$dbg env microservice=${msname} cap -s revision=${revision} hosts=${host} ${platform} deploy:setup \
			&& $dbg env microservice=${msname} cap -s revision=${revision} hosts=${host} ${platform} deploy
		done
		continue
        elif [ x"${product}" = x"priapi88" ]
        then
            for msdir in $(/bin/ls -1ad /mcorp/data/repository/php-api-* | grep -v built.git)
            do
                cd ${msdir}
                msname=$(basename ${msdir} | sed -e 's/.*php-api-//g')
                revision=$(eval cat \$${platform}_rsynccachedir/revision)
                [ "x$revision" = "x" ] && echo "failed to get las revision for microservice ${msname}" >&2 && continue
                $dbg env microservice=${msname} cap -s revision=${revision} hosts=${host} ${platform} deploy:setup \
                && $dbg env microservice=${msname} cap -s revision=${revision} hosts=${host} ${platform} deploy
            done
            continue
        fi	

	#deplacement dans le repertoire du produit
	projectdir="${repodir}/${product}"
	if [ ! -d $projectdir ]; then   
		echo "deploy aborted : ${product} dont exist"
		exit 1
	fi

	cd $projectdir 
	#recuperation de la version de prod 
	# peut etre differente de head si un rollback a été fait
	revision=$(eval cat \$${platform}_rsynccachedir/revision)
	if [ "x$revision" != "x" ] ; then 
		#deploiement de la version courante
		$dbg cap -s revision=${revision} hosts=${host} ${platform} deploy:setup \
		&& $dbg cap -s revision=${revision} hosts=${host} ${platform} deploy
	else
		echo "deploy aborted : failed to get last revision for ${product}"
		exit 1
	fi

done


exit 0

