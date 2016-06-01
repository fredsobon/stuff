#!/bin/bash

#set -x

#############################################################################################################
#Partie a modifiée.                                                                                         #
#############################################################################################################
# Partie Montages :#
####################
#Liste des montages netapp pour le snapshot :

mount_to_snap[1]='192.168.37.30:/vol/em_vmbrain_idx/em_vmbrain_idx'
mount_to_snap[2]='192.168.37.30:/vol/em_brain_dbf/em_brain_dbf'
mount_to_snap[3]='192.168.37.31:/vol/em_brain_idx/em_brain_idx'
mount_to_snap[4]='192.168.37.31:/vol/em_vmbrain_dbf/em_vmbrain_dbf'
mount_to_snap[5]='192.168.37.31:/vol/em_brain_undo/em_brain_undo'
mount_to_snap[6]='192.168.37.31:/vol/em_vmbrain_mvlog/em_vmbrain_mvlog'

#nombre_de_montages=6

#Répertoire des archives log :
arch_log_dir='192.168.37.30:/vol/em_brain_arch/em_brain_arch'

#Répertoire des redolog :
redo_dir='192.168.37.30:/vol/em_brain_redo/em_brain_redo'

#Répertoire Flash :
flash_dir='192.168.37.31:/vol/em_brain_flash/em_brain_flash'

#Répertoire OCR :
ocr_dir='192.168.37.31:/vol/em_brain_ocr/em_brain_ocr'

#Répertoire VOTE :
vote_dir='192.168.37.31:/vol/em_brain_vote1/em_brain_vote1'
vote_path=/data/oradata/RAC/VOTE

#Répertoire udump
udump_dir=/opt/oracle/product/10.2/admin/BRAINPIX/udump

#emplacement spfile:
spfile_path=/data/oradata/BRAINPIX/DBF/BRAINPIX/spfileBRAINPIX.ora

####################
#Partie Oracle     #
####################


ORACLE_SID=BRAINPIX1
NLS_LANG=FRENCH_FRANCE.AL32UTF8
LD_LIBRARY_PATH=/opt/oracle/product/10.2/db_1/lib:/lib:/usr/lib:/usr/local/lib
ORACLE_HOME=/opt/oracle/product/10.2/db_1
PATH=$PATH:/opt/oracle/product/10.2/db_1/bin


#Utilisateur netapp :
user_dbasnap=oracle
EMAIL=polebdd@fotovista.com

#############################################################################################################
#Fin de la partie a modifier                                                                               #
#############################################################################################################
export ORACLE_SID
export NLS_LANG
export LD_LIBRARY_PATH
export ORACLE_HOME
export PATH

sqlplus_bin=`/usr/bin/which sqlplus`
nombre_de_montages=${#mount_to_snap[*]}

#Fichiers temporaires:
verif_datafile=/tmp/verif_datafile.lst
spool_verif_tablespace=/tmp/verif_tablespace.lst
spool_relica_tablespace=/tmp/spool_relica_tablespace.lst
sort_verif_tablespace=/tmp/sort_verif_tablespace.lst
sort_relica_tablespace=/tmp/sort_relica_tablespace.lst
dbf_non_sauvegarder=/tmp/dbf_non_sauvegarder.lst
redo_non_sauvegarder=/tmp/redo_non_sauvegarder.lst

spool_begin_bck=/tmp/backup.sql
spool_end_backup=/tmp/backupend.sql
spool_redo_log=/tmp/redo_log.sql
spool_redo_log_resto=/tmp/spool_redo_log_resto.lst
spool_temp_resto=/tmp/temp.lst
spool_dbf_resto=/tmp/spool_dbf_resto.lst


resto_base=resto_base
date_bck=`date +%H`
date_ctrl=`date +%Y-%m-%d-%H`
temp_file=/tmp/tempfile.lst


#(( "$#" != 1 )) || USAGE

     case $1 in
     "hourly" | "HOURLY" )
     echo "Hourly Backup ..."
     modebackup='sv_hourly'
     ;;
     "daily"  | "DAILY" )
     echo "Daily Backup ..."
     modebackup='sv_daily'
     ;;
     "weekly" | "WEEKLY" )
     echo "Weekly Backup ..."
     modebackup='sv_weekly'
     ;;
     *)
     echo "Hourly is default mode backup"
     modebackup='sv_hourly'
     ;;
     esac


#############################################################################################################
#Fonctions snap,delete old snap  hotbackup, begin backup ...		               			    #
#############################################################################################################

#Function pour l'utilisation du script
USAGE()
{
        echo -e "\n\nUSAGE : `basename $0` TYPESNAP \n\n"
        exit 1
}

#Function d'envoi de mail:
ft_mail()
{
mail -s "Hotbackup ${ORACLE_SID} en erreur !!! " $EMAIL << END
.
END
}


#snapshot des montages

snapshot_montage(){
for i in `seq 1 ${nombre_de_montages}`
	do 
                ip_netapp=`echo ${mount_to_snap[${i}]} | awk -F : {'print $1'}`
                snap_name=`echo ${mount_to_snap[${i}]} | awk -F / '{print $NF}'`
#        echo  "ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup}"
                ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup}

        done
}

#Passage des tablespaces en mod backup :

begin_backup(){
${sqlplus_bin} / as sysdba <<EOF
set head off;
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_begin_bck}; 
select distinct 'alter tablespace ' || tablespace_name || ' begin backup;' from dba_data_files;
spool off;
exit;
EOF
cat ${spool_begin_bck} | grep -v "SQL>" > ${temp_file}
cat ${temp_file} > ${spool_begin_bck}

${sqlplus_bin} / as sysdba <<EOF
@${spool_begin_bck};
exit;
EOF
}

#Passage des tablespaces en mode normal :

end_backup(){
${sqlplus_bin} / as sysdba <<EOF
set head off;
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_end_backup};
select distinct 'alter tablespace ' || tablespace_name || ' end backup;' from dba_data_files;
spool off;
exit;
EOF
cat ${spool_end_backup} | grep -v "SQL>" > ${temp_file}
cat ${temp_file} > ${spool_end_backup}

${sqlplus_bin} / as sysdba <<EOF
@${spool_end_backup};
exit;
EOF
}

#Vérification que les bon dbf soient sauvegarder :

verification_dbf(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
${sqlplus_bin} / as sysdba <<EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_verif_tablespace};
select  FILE_NAME from DBA_DATA_FILES;
spool off;
EOF

j=1
for i in `cat ${spool_verif_tablespace} | grep -v "SQL>"`
	do
		datafile_to_backup[${j}]=${i}
		let "j=${j} + 1"
	done 

nb_datafile_to_backup=${j}

rm ${spool_relica_tablespace} 
for i in `seq 1 ${nombre_de_montages}`
	do 
		mountage_verif=`cat /etc/fstab | grep "${mount_to_snap[${i}]}" | awk {'print $2'}`
		cat ${spool_verif_tablespace} | grep ${mountage_verif}	>> ${spool_relica_tablespace}
done

cat ${spool_relica_tablespace} |  sort > ${sort_relica_tablespace}
cat ${spool_verif_tablespace}  | grep -v "SQL>" | sort > ${sort_verif_tablespace}

diff ${sort_relica_tablespace} ${sort_verif_tablespace} > ${dbf_non_sauvegarder}

if [ -s ${dbf_non_sauvegarder} ]
	then 
		echo "sauvegarde merdique"
		ft_mail
		cat ${dbf_non_sauvegarder}
		exit
fi

}

# Vérification du repertoire des redos:

verification_redo(){
${sqlplus_bin} / as sysdba <<EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_redo_log};
SELECT member FROM sys.v\$logfile;
spool off;
exit
EOF

cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile} 
rep_redo=`cat ${verif_datafile} | grep ${redo_dir} | awk {'print $2'}`
cat ${spool_redo_log} | grep -v ${rep_redo} | grep -v "SQL>" > ${redo_non_sauvegarder}

if [ -s ${redo_non_sauvegarder} ]
        then
                echo "sauvegarde merdique"
                cat ${redo_non_sauvegarder}
		ft_mail
                exit
fi

}

# Sauvegarde des redo :

sauve_redo(){
                ip_netapp=`echo ${redo_dir} | awk -F : {'print $1'}`
                snap_name=`echo ${redo_dir} | awk -F / '{print $NF}'`
#        echo  "ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup}"
                ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup}
}


#Switch des redo avant sauvegarde des archive log :
switch_redo(){
${sqlplus_bin} -s / as sysdba << EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
alter system archive log current;
exit;
EOF
}

#Sauvegarde du backup controlfile en mode texte: 
sauve_txt_ctrl_file(){
${sqlplus_bin} -s / as sysdba << EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
alter database backup controlfile to trace;
exit;
EOF

cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`
control_to_save=`ls -lrt ${udump_dir} |  tail -1 | awk {'print $8'}`
cp -p ${udump_dir}/${control_to_save} ${rep_arch}/control_to_trace_${date_ctrl}

}


#sauvegarde controle file apres backup
sauve_ctl_apres_bck(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

${sqlplus_bin} -s / as sysdba << EOF
alter database backup controlfile to '${rep_arch}/control01.ctl_apres_${date_ctrl}';
exit;
EOF
}

# Sauvegarde des archives log :
sauve_arch_log(){
                ip_netapp=`echo ${arch_log_dir} | awk -F : {'print $1'}`
                snap_name=`echo ${arch_log_dir} | awk -F / '{print $NF}'`
#        echo  "ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup}"
                ssh ${user_dbasnap}@$ip_netapp snapvault snap create ${snap_name} ${modebackup} >>/opt/oracle/mourad_snap.log
}

#Purge des fichiers obselete :
purge_finale(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

rm ${rep_arch}/control_to_trace_${date_ctrl}
rm ${rep_arch}/control01.ctl_apres_${date_ctrl}
rm ${rep_arch}/spfile_${date_ctrl}
rm ${rep_arch}/${resto_base}
rm -f ${rep_arch}/ocr_du_${date_ctrl}
rm ${rep_arch}/voting_disk_file_${date_ctrl}

}

#Création du fichier de restauration :
create_restau_file(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

path_resto_base=${rep_arch}/${resto_base}
#rm ${path_resto_base}

echo "### liste des fichiers dbf" > ${path_resto_base}

${sqlplus_bin} -s / as sysdba << EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 300;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_dbf_resto}
select file_name from dba_data_files order by file_name;
spool off
exit;
EOF

while read ligne
do
echo  ${ligne} >> ${path_resto_base}
done < ${spool_dbf_resto}


echo "### restauration des dbf" >> ${path_resto_base}
for i in `seq 1 ${nombre_de_montages}`
        do
                ip_netapp=`echo ${mount_to_snap[${i}]} | awk -F : {'print $1'}`
                snap_name=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
                snap_to_do_date=$modebackup ||".XXX_voir_l_heure_de_restauration_souhaitee"
            #    snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
                echo "ssh ${user_dbasnap}@$ip_netapp snap restore -s ${snap_to_do_date} ${snap_name}" >> ${path_resto_base}
        done

echo "### restauration des redo" >> ${path_resto_base}
		ip_netapp=`echo ${redo_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${redo_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${redo_dir} |  awk -F / '{print $NF}'`
            #    snap_to_do_date="sv_hourly.XXX_voir_l_heure_de_restauration_souhaitee"
                snap_to_do_date=$modebackup ||".XXX_voir_l_heure_de_restauration_souhaitee"
 
            #    snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
                echo "ssh ${user_dbasnap}@$ip_netapp snap restore -s ${snap_to_do_date} ${snap_name}" >> ${path_resto_base}

echo "### restauration des fichiers archives log" >> ${path_resto_base}
		ip_netapp=`echo ${arch_log_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${arch_log_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${arch_log_dir} |  awk -F / '{print $NF}'`
            #    snap_to_do_date="sv_hourly.XXX_voir_l_heure_de_restauration_souhaitee"
                snap_to_do_date=$modebackup ||".XXX_voir_l_heure_de_restauration_souhaitee"
              
            #    snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
                echo "ssh ${user_dbasnap}@$ip_netapp snap restore -s ${snap_to_do_date} ${snap_name}" >> ${path_resto_base}

echo "### copie des fichiers de controles" >> ${path_resto_base}

${sqlplus_bin} -s / as sysdba << EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 150;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_redo_log_resto}
SELECT distinct RPAD(SUBSTR(name,1,50),51,' ') "CONTROL FILE NAME" FROM gv\$controlfile;
spool off
exit;
EOF

while read ligne
do 
echo "cp ${rep_arch}/control01.ctl_apres_${date_ctrl} ${ligne}" >> ${path_resto_base}
done < ${spool_redo_log_resto} 

echo "### creation des fichiers temporaires" >> ${path_resto_base}

${sqlplus_bin} -s / as sysdba << EOF
set echo off;
set termout off;
set feedback off;
set pause off;
set head off;
set line 300;
SET NEWPAGE none;
SET PAGESIZE 0 ;
spool ${spool_temp_resto}
select 'CREATE TEMPORARY TABLESPACE '|| tablespace_name || ' TEMPFILE '''||FILE_NAME ||''' SIZE '|| BYTES || ' AUTOEXTEND ON NEXT 100M MAXSIZE '|| MAXBYTES || ' EXTENT MANAGEMENT LOCAL UNIFORM SIZE 1M;' 
from dba_temp_files
order by tablespace_name;
spool off
exit;
EOF

while read ligne
do
echo  ${ligne} >> ${path_resto_base}
done < ${spool_temp_resto}

echo "### creation du voting" >> ${path_resto_base}
echo "dd if=${rep_arch}/voting_disk_file_${date_ctrl} of=${vote_path}/votefile" >> ${path_resto_base}

echo "### creation de l ocr" >> ${path_resto_base}
echo "sudo /opt/oracle/product/10.2/crs_1/bin/ocrconfig -import ${rep_arch}/ocr_du_${date_ctrl}" >> ${path_resto_base}

echo "### verification de l ocr" >> ${path_resto_base}
echo "cluvfy comp ocr -n all" >> ${path_resto_base}

}

#Sauvegarde_spfile
sauvegarde_spfile(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

if [ -e ${spfile_path} ]
	then 
		cp ${spfile_path} ${rep_arch}/spfile_${date_ctrl}
	else 
		echo "SPFILE : ca pue"
		ft_mail
fi
}

#Sauvegarde ocr
sauvegarde_ocr(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

if [ -e ${ocr_bck_path} ]
  then
#    cp ${ocr_bck_path}/*.ocr ${rep_arch}/*.ocr
  sudo /opt/oracle/product/10.2/crs_1/bin/ocrconfig -export ${rep_arch}/ocr_du_${date_ctrl} -s online
	else 
		echo "OCR : ca pue"
fi
}

#Sauvegarde voting
sauvegarde_voting(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

if [ -e ${vote_path} ]
        then
    dd if=${vote_path}/votefile of=${rep_arch}/voting_disk_file_${date_ctrl}
        else
        echo "VOTING : ca pue"
fi

}


#############################################################################################################
#    Execution du backup                                                                                    #
#############################################################################################################
if [ $1=="archiv" ]
then


       echo "Backup only Archivelog OCR Voting and control file"
       create_restau_file
       switch_redo
       sauve_txt_ctrl_file
       sauvegarde_spfile
       sauvegarde_ocr
       sauvegarde_voting
       sauve_ctl_apres_bck
       sauve_arch_log
       purge_finale
        echo "ARCH"
else
        echo "Backup full"
        echo "DBF"
        
	create_restau_file
        verification_dbf
        verification_redo
        sauve_txt_ctrl_file
        begin_backup
        snapshot_montage
        end_backup
        sauve_ctl_apres_bck
        switch_redo
        sauve_redo
        sauvegarde_spfile
        sauve_arch_log
        sauvegarde_ocr
        sauvegarde_voting
        purge_finale
fi

