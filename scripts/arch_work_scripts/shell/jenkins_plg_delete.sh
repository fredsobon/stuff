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

Remove plugin

Usage:
    jenkins_plg_delete.sh  -n|--name <plugin>  [<options>] 
        
Arguments :

   -n | --name <plugin>
         Nom de plugin à  supprimer

[Optionnel]

   -l | --list 
         Lister les plugins installés 


[Divers]
   -h | --help
         Affiche cette aide

 

EOF
if [ -n "$LISTE" ]; then
echo "Plugins installés :"
#/bin/bash /root/plugin_jenkins_up.sh

cd $FOLDER_PLUGIN
n=0
for plg in $(ls *.* |awk -F "." '{print$1}');
do
      version=$(cat $FOLDER_PLUGIN/$plg/META-INF/MANIFEST.MF | grep Plugin-Ver|awk -F ": " '{print$2}'| awk '{ sub(/\r$/,""); print }')
      list_o[$n]=$plg
      list_ro[$n]=$version
      n=$(expr $n + 1)
done

n=$(expr $n - 1)
for i in $(seq 0 $n)
do
        echo " --> ${list_o[$i]} (Release:${list_ro[$i]})  "
done

fi
}
list_plugin(){
echo "Plugins installés :"
#/bin/bash /root/plugin_jenkins_up.sh

cd $FOLDER_PLUGIN
n=0
for plg in $(ls *.* |awk -F "." '{print$1}');
do
    version=$(cat $FOLDER_PLUGIN/$plg/META-INF/MANIFEST.MF | grep Plugin-Ver|awk -F ": " '{print$2}'| awk '{ sub(/\r$/,""); print }')
    list_o[$n]=$plg
    list_ro[$n]=$version
    n=$(expr $n + 1)

done

n=$(expr $n - 1)
for i in $(seq 0 $n)
do
        echo " --> ${list_o[$i]} (Release:${list_ro[$i]} ) "
done

}

remove_plugin(){
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

echo "Removing plugin ....:\n" 
cd $FOLDER_PLUGIN
for file in $(ls $1.*);
do
rm -f $file
done
rm -rf $FOLDER_PLUGIN/$1

/etc/init.d/jenkins restart
/etc/init.d/apache2 restart

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
val=$(ls -d /var/lib/jenkins/plugins/*/ |grep "$PLUGIN" |wc -l)

if [ "$val" != "1" ]; then
        echo "Plugin not installed yet! " 
        echo 'abording...' >&2
        exit 1
fi

val=0

echo  "Plugin  : $PLUGIN"

remove_plugin $PLUGIN 
echo "END ./" 

