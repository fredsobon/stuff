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

Add plugin

Usage:
    jenkins_plg_install.sh  -i | --inst  -n | --name [<options>] 
        
Arguments :
    -i | --inst
          Lancer le processus d'installtion 
    -n | --name
	  Nom du plugin à installer

[Optionnel]

   -l | --list 
         Lister les plugins à installer 
   -v | --version 
          La version du plugin à installer ( latest si valeur null )
 


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
echo "Plugins à installer   :"
cd $PLUGIN_CIBLE
m=1
for plg in $(ls |grep  "_I" );
do
       echo "$m: $plg "
       list_all[$m]=$plg
       m=$(expr $m + 1)

done
        echo "$m: Exit "
       list_all[$m]="Exit"
fi
}

install_plugin(){

cd $PLUGIN_CIBLE
#m=1
#for plg in $(ls |grep  "_I");
#do
#       echo "$m: $plg "
#       list_all[$m]=$plg
#       m=$(expr $m + 1)

#done
   
#if [[ $m = 1 ]]; then
#        echo " Aucun plugins à installer ! "
#        exit
#fi

#       echo "$m: Exit "
#       list_all[$m]="Exit"

#echo -n "Chosir le plugin à installer  : "

#read answer

#if [[ $answer = ?([-+])+([0-9]) ]];
#then
#       if [ "$answer" -gt "$m" ]; then
#            echo "Votre choix doit être inférieur à  $m" >&2
#            install_plugin
#       else
#           if [[ ${list_all[$answer]} == "Exit" ]]; then
#               echo 'abording...' >&2
#               exit 1
#            else
plugin=`echo ${list_all[$answer]} |awk -F "--" '{print$1}'|awk '{ sub(/\r$/,""); print }'`

echo -e " Le plugin à installer est : $1 version $2"
echo -e " Début installation  ...\n"
mv -f  $PLUGIN_CIBLE/$1.hpi--${2}_I  $FOLDER_PLUGIN
rm -f $PLUGIN_CIBLE/$1.hpi--${2}_I 
mv $FOLDER_PLUGIN/$1.hpi--${2}_I  $FOLDER_PLUGIN/$1.hpi

/etc/init.d/jenkins restart
/etc/init.d/apache2 restart
#	fi
#       fi

#else
#echo "Votre choix doit être numérique  !" 
#install_plugin
#fi
}
while [ $# -ne 0 ]; do
        case $1 in
                '--inst'|'-i')
                        INST=1
                        ;;
		'--name'|'-n')
                        PLUGIN=$2
			;;
		'--version'|'-v')
                        RELEASE=$2
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

if [  -z "$RELEASE"  ] ; then 
RELEASE="LATEST"
fi 
# Check mandatory parameters
if [ -z "$INST" ] || [ -z "$PLUGIN" ] ; then

if [ -n "$LISTE" ] ; then
  cd $PLUGIN_CIBLE
  m=1
  for plg in $(ls |grep "_I");
   do
       echo "$m: $plg "
       list_all[$m]=$plg
       m=$(expr $m + 1)
   done
  if [[ $m = 1 ]]; then
     echo " Aucun plugins à installer ! "
     exit
  fi

  echo "$m: Exit "
  list_all[$m]="Exit"
  exit
else
  usage
  exit
fi
else
install_plugin $PLUGIN $RELEASE 
fi

