#!/usr/bin/env bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26
URL_JENKINS_UPDATE_PLUGIN_LAST="updates.jenkins-ci.org/latest/"
URL_JENKINS_UPDATE_PLUGIN_OTHER="updates.jenkins-ci.org/download/plugins"
SERVER_CI="ci01.svc.core.dev.vit.e-merchant.net"
FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_CIBLE="/root/plugin_jenkins_cible"
PLUGIN_OLD="/var/lib/jenkins/old_plugin_stable"

usage() {
        cat <<EOF

Update plugin

Usage:
    update_plugins.sh  -n|--name <plugin> -v|--version <release> [<options>] 
        
Arguments :

   -n | --name <plugin>
         Nom de plugin à mettre à jour
   -v | --version <release>
         La version cible

[Optionnel]

   -l | --list 
         Lister les plugins installés 
   -d | --dispo


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
echo "Plugins installés :"
/bin/bash /root/plugin_jenkins_up.sh
fi

if [ -n "$DISPO" ]; then 
cd $PLUGIN_CIBLE
  m=1
  for plg in $(ls |grep -i "_U" );
     do
       list_all[$m]=$plg
        m=$(expr $m + 1)
     done
      #list_all[$m]="Exit"
     if [ $m = 1 ] ; then
        echo " Aucun plugins dispo pour la mise à jour" 
      else
        echo " PLUGINS DISPONIBLE POUR LA MISE A JOUR :"
        for i in $(seq 1 $m);
           do
              echo ${list_all[$i]}
           done
       fi

fi 

}
list_plugin(){
echo "Plugins installés :"
/bin/bash /root/plugin_jenkins_up.sh
/bin/echo -e "\n\n"

}

update_plugin(){
#/bin/ls $PLUGIN_CIBLE|grep "${1}.hpi--${2}"
#echo "${1}.hpi--${2}"
val=`/bin/ls $PLUGIN_CIBLE|grep "${1}.hpi--${2}"|wc -l`
echo $val

if [ "$val" != "1" ]; then

        echo "No target plugin is avialable."
        echo "Must transfert the plugin to update ($1.hpi) in /root/plugin_jenkins_cible"
else
        /bin/echo -e "save current plugin ....:\n" 
        cd $FOLDER_PLUGIN
        version=$(cat $FOLDER_PLUGIN/$1/META-INF/MANIFEST.MF | grep Plugin-Ver|awk -F ": " '{print$2}'| awk '{ sub(/\r$/,""); print }')	
        mkdir $PLUGIN_OLD/$1--release-$version
        for file in $(ls $1.*);
            do
                echo $file
                cp $file $PLUGIN_OLD/$1--release-$version/$file
            done
        cp -R $FOLDER_PLUGIN/$1 $PLUGIN_OLD/$1--release-$version/$1
        echo "Beginning of update ....:\n" 

        mv $PLUGIN_CIBLE/$1.hpi--${2}_U $FOLDER_PLUGIN/$1.hpi
        #echo -n "do you want to update this plugin Now ? (y/n)"
        #read answer
        #        if [ "$answer" != 'y' ] && [ "$answer" != 'Y' ] ; then
        #                echo "abording..." >&2
	#		exit
        #        fi

/etc/init.d/jenkins restart
/etc/init.d/apache2 restart

echo " END"
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
 		' --dispo'|'-d')
			DISPO=1
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
        if [ -n "$LISTE" ]; then
           list_plugin
           cd $PLUGIN_CIBLE
	   
	   m=1
	   for plg in $(ls |grep "_U" );
	   do
               # echo "$m: $plg "
                list_all[$m]=$plg
                m=$(expr $m + 1)

	    done
        	#echo "$m: Exit "
       		#list_all[$m]="Exit"
	     if [ $m = 1 ] ; then 
		echo " Aucun plugins dispo pour la mise à jour" 
		exit
	      else
                echo " PLUGINS DISPONIBLE POUR LA MISE A JOUR :"
		for i in $(seq 1 $m); 
		do
			echo ${list_all[$i]}
		done
                exit
	       fi	
        else
        usage
        exit
        fi
fi



# Check PLUGIN 
val=$(ls -d /var/lib/jenkins/plugins/*/ |grep "$PLUGIN" |wc -l)

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

echo " Start update $PLUGIN ... " 
update_plugin $PLUGIN $RELEASE
echo "END ./" 

