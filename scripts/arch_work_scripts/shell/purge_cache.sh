#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-09-13

DNS_SEARCH=`which dns_search`
if [ -z ${DNS_SEARCH} ]; then
	echo "Error: command 'dns_search' not found"
	exit 1
fi

usage() {
        cat <<EOF

Purge cache ( memcache | varnish | static)

Usage:
    purge_cache.sh  -f|--fonction <fonction> -p|--plateforme <plateforme> -e|--environnement <environnement> -t|--type <type_cache>  -x|--action 

Arguments :

   -f | --fonction <fonction>
         (MEMCACH : front, back, svc, all  OU VARNISH : back, front, all)

   -p | --plateforme <Plateforme>
         (MEMCACHE : cfour, pix, mutu, all ou VARNISH : cfour, pix, mutu, corepub, all)
   -e | --environnement <Environnement>
         (dev, uat, prod)
   -t | --type <Type de cache>  
         (memcache, varnish, static, all)
        Option all -->  purge cache en respectant l'ordre memcache puis varnish  
   -x | --action <Action> 
         ( start, stop, restart, status)


[Divers]
   -h | --help

EOF
}


while [ $# -ne 0 ]; do
        case $1 in
                '--fonction'|'-f')
                        FONCTION=$2
                        ;;
                '--plateforme'|'-p')
                        PLATEFORME=$2
                        ;;
                '--environnement'|'-e')
                        ENV=$2
                        ;;
                '--type'|'-t')
                        TYPE_CACHE=$2
                        ;;
        		'--action'|'-x')
                        ACTION=$2
                        ;;
                '--help'|'-h')
                        usage
                        exit
                        ;;
                           *)
                        ;;
        esac
        shift
done
clear 
if [ "$PLATEFORME" = "all" ]
then
PLATEFORME="*"
fi

if [ "$FONCTION" = "all" ]; then FONCTION="*"; fi
if [ "$TYPE_CACHE" = "all" ]; then TYPE_CACHE="memvar"; fi

list_server_memcache=`$DNS_SEARCH ^cach.?0.*.$FONCTION.$PLATEFORME.$ENV |awk '{print$1}'`
list_server_varnish=`$DNS_SEARCH ^rp.?0.*.$FONCTION.$PLATEFORME.$ENV |awk '{print$1}'`
list_server_static=`$DNS_SEARCH ^static.?0.*.$FONCTION.$PLATEFORME.$ENV |awk '{print$1}'`

# Check mandatory parameters
if [ -z "$FONCTION" ] || [ -z "$PLATEFORME" ] || [ -z "$ENV" ] || [ -z "$TYPE_CACHE" ] || [ -z "$ACTION" ] ; then
     usage
     exit
fi
if [ "$TYPE_CACHE" ]; then
CONST=$TYPE_CACHE
if [ "$TYPE_CACHE" = "memvar" ]; then CONST="Memcahe & Varnish"; fi

echo "La liste des serveurs $CONST :"
     case $TYPE_CACHE in
        varnish)
        echo "$list_server_varnish"
           ;;
        static)
        echo "$list_server_static"
           ;;
        memvar)
        echo "MEMCACHE :\n"
        echo  "$list_server_memcache"   
        echo "\n\n"
        echo "VARNISH :\n"
        echo "$list_server_varnish"
           ;;
        memcache|memcach)
        echo "MEMCACHE :\n"
        echo  "$list_server_memcache" 
           ;;
         esac
fi
echo "\n\n"

echo "Vous allez lancer  la commande \"service $TYPE_CACHE $ACTION \"... ! \n"
echo -n "Voulez vous continuer ? (o/n) "
read rep

echo "\n\n"
if [ "$rep" = "o" ] || [ "$rep" = "O" ]
then


case $TYPE_CACHE in 

memcache|memcach)

for srv in $list_server_memcache 
do
echo $srv 
ssh -o StrictHostKeyChecking=no $srv " /etc/init.d/memcached $ACTION ; /etc/init.d/memcached-sessions $ACTION "
done

;;

varnish)

for srv in $list_server_varnish
do
echo $srv
ssh -o StrictHostKeyChecking=no $srv " service varnish $ACTION "
done

;;

static)
for srv in $list_server_static
do
echo $srv
ssh -o StrictHostKeyChecking=no $srv " service varnish $ACTION "
done
;;
memvar)
## memcache 
echo " Purge memcache ....\n"
for srv in $list_server_memcache
do
echo $srv 
ssh -o StrictHostKeyChecking=no $srv " /etc/init.d/memcached $ACTION ; /etc/init.d/memcached-sessions $ACTION "
done

## varnish
echo "\n\n"
echo " Purge varnish ....\n"
for srv in $list_server_varnish
do
echo $srv
ssh -o StrictHostKeyChecking=no $srv " service varnish $ACTION "
done

;;
esac
else
echo "Exit"
fi  

