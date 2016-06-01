#!/usr/bin/env bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26
SERVER_CI="ci01.svc.core.prod.e-merchant.net"
FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_CIBLE="/root/plugin_jenkins_cible"
PLUGIN_OLD="/var/lib/jenkins/old_plugin_stable"

usage() {
        cat <<EOF

Remove plugin

Usage:
    delete_plugin.sh  -n|--name <plugin>  [<options>] 
        
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
ssh $SERVER_CI "/bin/bash /usr/local/bin/jenkins_plg_up.sh"
fi
}

list_plugin(){
echo "Plugins installés :"
#/bin/bash /root/plugin_jenkins_up.sh
ssh $SERVER_CI "/bin/bash /usr/local/bin/jenkins_plg_up.sh"

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

ssh $SERVER_CI " /bin/bash /usr/local/bin/jenkins_plg_delete.sh -n $PLUGIN "
echo " END/." 

