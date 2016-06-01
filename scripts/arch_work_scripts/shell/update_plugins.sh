#!/bin/sh
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26
URL_JENKINS_UPDATE_PLUGIN_LAST="updates.jenkins-ci.org/latest/"
URL_JENKINS_UPDATE_PLUGIN_OTHER="updates.jenkins-ci.org/download/plugins"
SERVER_CI="ci02.svc.core.prod.dc3.e-merchant.net"
FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_CIBLE="/root/plugin_jenkins_cible"


usage() {
        cat <<EOF

Update plugin

Usage:
    update_plugins.sh  -n|--name <plugin> -v|--version <release> [<options>] 
	
Arguments :

   -n | --name <plugin>
         Nom de plugin a mettre a jour
   -v | --version <release>
         La version cible

[Optionnel]

   -l | --list 
         Lister les plugins installes 
   -L | --detail 
          Liste detaillee des plugins non a jour  


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
echo "Plugins installes :"
ssh $SERVER_CI " /bin/bash /usr/local/bin/jenkins_plg_up.sh "
fi
}

list_plugin(){
echo "Plugins installes :"
if [ -n "$DETAIL" ] ; then 
ssh $SERVER_CI " /bin/bash /usr/local/bin/plugin_jenkins_up.sh "
else
ssh $SERVER_CI " /bin/bash /usr/local/bin/jenkins_plg_up.sh "
fi
/bin/echo -e "\n\n"

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
		'--detail'|'-L')
			DETAIL=1
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
if [ -z "$PLUGIN" ] || [ -z "$RELEASE" ]; then
	if [ -n "$LISTE" ] || [ -n "$DETAIL" ]; then
	   list_plugin
	   exit
	else
        usage
        exit 
	fi
fi



# Check PLUGIN 
val=$(ssh $SERVER_CI "ls -d /var/lib/jenkins/plugins/*/" |grep "$PLUGIN" |wc -l)

if [ "$val" != "1" ]; then 
	echo "Plugin not installed yet! " 
        echo 'abording...' >&2
        exit 1
fi 

val=0
# Check RELEASE 

val=$(curl -s https://$URL_JENKINS_UPDATE_PLUGIN_OTHER/$PLUGIN/ |grep "$RELEASE" |wc -l)

if [ "$val" != "1" ]; then
        echo "Release of $PLUGIN  not exist " 
        echo 'abording...' >&2
        exit 1
fi

echo  "Plugin  : $PLUGIN"
echo  "Target release  : $RELEASE" 

echo " Start download $PLUGIN ... " 
cd /tmp
wget https://$URL_JENKINS_UPDATE_PLUGIN_OTHER/$PLUGIN/$RELEASE/$PLUGIN.hpi -o /dev/null

echo " Start Transfer to Jankin's server ..."
mv /tmp/$PLUGIN.hpi /tmp/$PLUGIN.hpi--${RELEASE}_U

scp /tmp/$PLUGIN.hpi--${RELEASE}_U $SERVER_CI:$PLUGIN_CIBLE/

#ssh $SERVER_CI "/bin/bash /usr/local/bin/jenkins_plg_update.sh -n $PLUGIN -v $RELEASE "
#read answer
#    if [ "$answer" != 'y' ] && [ "$answer" != 'Y' ] ; then
#      echo "abording..." >&2
#      exit
#    fi

#ssh $SERVER_CI "/etc/init.d/jenkins restart ; /etc/init.d/apache2 restart"


#echo "To finish the update should start 'jenkins_plg_update.sh' script on jenkins server and follow instructions" 
echo "END ./" 


