#!/usr/bin/env bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-06-13
URL_JENKINS_UPDATE_PLUGIN_LAST="updates.jenkins-ci.org/latest/"
URL_JENKINS_UPDATE_PLUGIN_OTHER="updates.jenkins-ci.org/download/plugins"
SERVER_CI="ci01.svc.core.dev.vit.e-merchant.net"
FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_CIBLE="/root/plugin_jenkins_cible"
PLUGIN_OLD="/var/lib/jenkins/old_plugin_stable"

usage() {
        cat <<EOF

Roll-Back plugin

Usage:
    jenkins_plg_rollback.sh  -n|--name <plugin>  [<options>] 
        
Arguments :

   -n | --name <plugin>
         Nom de plugin à mettre à jour

[Optionnel]

   -l | --list 
         Lister les plugins récemment misent à jour 


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
echo "Plugins récemment misent à jour ou supprimés  :"
cd $PLUGIN_OLD
m=1
for plg in $(ls  );
do
       echo "$m: $plg "
       list_all[$m]=$plg
       m=$(expr $m + 1)

done
        echo "$m: Exit "
       list_all[$m]="Exit"

fi
}

while [ $# -ne 0 ]; do
        case $1 in
                '--name'|'-n')
                        PLUGIN=$2
                        ;;
                '--list'|'-l')
                        LISTE=1
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


rollback_plugin(){
echo "Plugins récemment misent à jour ou supprimés  :"
cd $PLUGIN_OLD
m=1
for plg in $(ls  );
do
       echo "$m: $plg "
       list_all[$m]=$plg
       m=$(expr $m + 1)

done
   
if [[ $m = 1 ]]; then
        echo " Aucun plugins à restaurer ! "
        exit
fi

       echo "$m: Exit "
       list_all[$m]="Exit"

echo -n "Chosir le plugin à restaurer : "

read answer

if [[ $answer = ?([-+])+([0-9]) ]];
then
       if [ "$answer" -gt "$m" ]; then
            echo "Votre choix doit être inférieur à  $m" >&2
            rollback_plugin
       else
            if [[ ${list_all[$answer]} == "Exit" ]]; then
               echo 'abording...' >&2
               exit 1
            else
	    plugin=`echo ${list_all[$answer]} |awk -F "--" '{print$1}'`
            echo -e " Le plugin à restaurer est : $plugin"
            echo -e " Start roll back ...\n"
            rm -rf $FOLDER_PLUGIN/$plugin
            mv -f  $PLUGIN_OLD/${list_all[$answer]}/*  $FOLDER_PLUGIN
            chown -R jenkins:nogroup $FOLDER_PLUGIN/$plugin
            rm -rf $PLUGIN_OLD/${list_all[$answer]}
            /etc/init.d/jenkins restart
            /etc/init.d/apache2 restart
            echo -n "Voulez vous restaurer un autre plugin ? (O/N)"
                read answer
                if [ "$answer" != 'o' ] && [ "$answer" != 'O' ] ; then
                        echo 'abording...' >&2
			exit                        
                fi
            rollback_plugin
            fi
       fi

else
echo "Votre choix doit être numérique  !" 
rollback_plugin
fi
}

rollback_plugin
