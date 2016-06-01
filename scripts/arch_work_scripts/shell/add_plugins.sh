#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26
URL_JENKINS_UPDATE_PLUGIN_LAST="updates.jenkins-ci.org/latest/"
URL_JENKINS_UPDATE_PLUGIN_OTHER="updates.jenkins-ci.org/download/plugins"
SERVER_CI="ci01.svc.core.prod.vit.e-merchant.net"
FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_CIBLE="/root/plugin_jenkins_cible"


usage() {
        cat <<EOF

Add plugin

Usage:
   add_plugins.sh  -n|--name <plugin>  [<options>] 
	
Arguments :

   -n | --name <plugin>
         Nom de plugin à installer

[Optionnel]

   -l | --list 
         Lister les plugins disponible
   -L | --like 
         Pour faire une recherche sur les premiers lettres du plugin 
   -v | --vesrion 
	 La version du plugin à installer ( latest si valeur null )
	


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
  if [ -z "$LIKE" ] ; then 
	echo "Plugins disponible :"
	curl -s https://updates.jenkins-ci.org/download/plugins/ |grep "href"| awk -F "href="\" '{print$2}'|awk -F "/" '{print$1}'  |grep -v "?C=" 
  else 
	echo "Plugins disponible :"
        curl -s https://updates.jenkins-ci.org/download/plugins/ |grep "href"| awk -F "href="\" '{print$2}'|awk -F "/" '{print$1}'  |grep -v "?C="|grep -i ^"$LIKE"
  fi
fi
}

list_plugin(){
echo "Plugins disponible :"
if [ -z "$LIKE" ] ; then 
curl -s https://updates.jenkins-ci.org/download/plugins/ |grep "href"| awk -F "href="\" '{print$2}'|awk -F "/" '{print$1}' |grep -v "?C="
else
curl -s https://updates.jenkins-ci.org/download/plugins/ |grep "href"| awk -F "href="\" '{print$2}'|awk -F "/" '{print$1}' |grep -v "?C="|grep  -i ^"$LIKE"
fi
}

while [ $# -ne 0 ]; do
        case $1 in
                '--name'|'-n')
                        PLUGIN=$2
                        ;;
		'--version'|'-v')
			RELEASE=$2
			;;
		'--list'|'-l')
			LISTE=1
			;;
                '--like'|'-L')
			LIKE=$2
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




# Check mandatory parameters
if [ -z "$PLUGIN" ] ; then
	if [ -n "$LISTE" ]; then
	   list_plugin
	   exit
	else
        usage
        exit 
	fi
fi


# Check PLUGIN 
 
val=$(curl -s https://updates.jenkins-ci.org/download/plugins/ |grep "href"| awk -F "href="\" '{print$2}'|awk -F "/" '{print$1}'  |grep -v "?C="|more |grep  "^$PLUGIN$" |wc -l)

if [ "$val" != "1" ]; then 
	echo "Plugin n'est disponible " 
        echo 'abording...' >&2
        exit 1
fi 

# Start Download & Check RELEASE 



val=$(ssh $SERVER_CI " ls -d $FOLDER_PLUGIN/*/" |grep $PLUGIN |wc -l) 
echo $val

if [ $val = 0 ] ; then 

	cd /tmp

	if [ -z "$RELEASE" ] ; then 


		wget https://updates.jenkins-ci.org/latest/$PLUGIN.hpi -o /dev/null
		CIBLE=`curl -I -s https://updates.jenkins-ci.org/latest/$PLUGIN.hpi |grep Location |awk -F "/" '{print$(NF-1)}'`
		echo  "Plugin  : $PLUGIN"
		echo  "Target release  : $CIBLE" 
                if [ "$CIBLE" != "" ]; then 
		echo " Start Transfer to Jankin's server ..."
		mv /tmp/$PLUGIN.hpi /tmp/$PLUGIN.hpi--LATEST_I
		scp /tmp/$PLUGIN.hpi--LATEST_I $SERVER_CI:$PLUGIN_CIBLE/
		ssh $SERVER_CI "/bin/bash /usr/local/bin/jenkins_plg_install.sh -i -n $PLUGIN "
		echo "END ./" 
                else
		echo " Cette version de Plugin non disponible pour le moment !!"
		exit
		fi
	else	
		val=$(curl -s https://$URL_JENKINS_UPDATE_PLUGIN_OTHER/$PLUGIN/ |grep "$RELEASE" |wc -l)
		if [ "$val" != "1" ]; then
		        echo "Release of $PLUGIN  not exist " 
		        echo 'abording...' >&2
		        exit 1
                fi

		CIBLE=$RELEASE 
                chk=`curl -I -s https://$URL_JENKINS_UPDATE_PLUGIN_OTHER/$PLUGIN/$RELEASE/$PLUGIN.hpi |grep Location |awk -F "/" '{print$(NF-1)}'`
		if [ "$chk" != "" ]; then 
		pwd
		wget https://$URL_JENKINS_UPDATE_PLUGIN_OTHER/$PLUGIN/$RELEASE/$PLUGIN.hpi 
		echo  "Plugin  : $PLUGIN"
                echo  "Target release  : $CIBLE"
		echo " Start Transfer to Jankin's server ..."
                mv /tmp/$PLUGIN.hpi /tmp/$PLUGIN.hpi--${CIBLE}_I
                scp /tmp/$PLUGIN.hpi--${CIBLE}_I $SERVER_CI:$PLUGIN_CIBLE/
		ssh $SERVER_CI "/bin/bash /usr/local/bin/jenkins_plg_install.sh -i -n $PLUGIN -v $RELEASE " 
                echo "END ./" 
		else
		echo " Cette version de Plugin non disponible pour le moment !!"
                exit
                fi


	fi

else

echo " $PLUGIN exist déjà !!" 

fi 


