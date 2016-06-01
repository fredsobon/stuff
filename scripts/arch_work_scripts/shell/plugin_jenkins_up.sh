#!/usr/bin/env bash
# vim: ts=4 sw=4
# Abdelaziz LAMJARHJARH  2014-05-26

FOLDER_PLUGIN="/var/lib/jenkins/plugins"
PLUGIN_OLD="/var/lib/jenkins/old_plugin_stable"

PLUGIN_CIBLE="/root/plugin_jenkins_cible"

cd $FOLDER_PLUGIN
echo -e "List installed plugins: \n"
n=0
m=0
for plg in $(ls *.* |awk -F "." '{print$1}');
do
        version=$(cat $FOLDER_PLUGIN/$plg/META-INF/MANIFEST.MF | grep Plugin-Ver|awk -F ": " '{print$2}'| awk '{ sub(/\r$/,""); print }')
        cible=`curl -I -s https://updates.jenkins-ci.org/latest/$plg.hpi |grep Location |awk -F "/" '{print$(NF-1)}'`
        if [[ ${version} != ${cible} ]];
        then
                #echo " $plg ( curent release : $version)  --> Target version is : $cible"
                list_o[$n]=$plg
                list_ro[$n]=$version
                list_tr[$n]=$cible
                n=$(expr $n + 1)
        else
                #echo " $plg ( curent release : $version)"
                list_n[$m]=$plg
                list_rn[$m]=$cible
                m=$(expr $m + 1)
        fi

done

m=$(expr $m - 1)
n=$(expr $n - 1)
echo "Last release: "
for i in $(seq 0 $m)
do
        echo " --> ${list_n[$i]} (Release: ${list_rn[$i]}) "
done
echo -e "\n"
echo "Release  may be updated :"
for i in $(seq 0 $n)
do
        echo " --> ${list_o[$i]} (Release:${list_ro[$i]}   --> Last release : ${list_tr[$i]})"
done


