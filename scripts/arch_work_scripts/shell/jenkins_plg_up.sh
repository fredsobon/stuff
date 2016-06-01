#!/usr/bin/env bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26

FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_OLD="/var/lib/jenkins/old_plugin_stable"

PLUGIN_CIBLE="/root/plugin_jenkins_cible"

cd $FOLDER_PLUGIN
echo -e "List installed plugins: \n"
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


