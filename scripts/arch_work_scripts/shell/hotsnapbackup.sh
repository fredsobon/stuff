#!/bin/bash

#set -x

#############################################################################################################
#Partie a modifiée.                                                                                         #
#############################################################################################################
# Partie Montages :#
####################
#Liste des montages netapp pour le snapshot :

mount_to_snap[1]='192.168.37.31:/vol/em_sourcing_idx/em_sourcing_idx'
mount_to_snap[2]='192.168.37.31:/vol/em_geoloc_idx/em_geoloc_idx'
mount_to_snap[3]='192.168.37.31:/vol/em_passerelle_idx/em_passerelle_idx'
mount_to_snap[4]='192.168.37.30:/vol/em_affil_idx/em_affil_idx'
mount_to_snap[5]='192.168.37.30:/vol/em_gtwdsg_idx/em_gtwdsg_idx'
mount_to_snap[6]='192.168.37.30:/vol/em_vmtools_idx/em_vmtools_idx'
mount_to_snap[7]='192.168.37.30:/vol/em_ref_idx/em_ref_idx'
mount_to_snap[8]='192.168.37.31:/vol/em_affil_dbf/em_affil_dbf'
mount_to_snap[9]='192.168.37.31:/vol/em_gtwdsg_dbf/em_gtwdsg_dbf'
mount_to_snap[10]='192.168.37.31:/vol/em_vmtools_dbf/em_vmtools_dbf'
mount_to_snap[11]='192.168.37.31:/vol/em_ref_dbf/em_ref_dbf'
mount_to_snap[12]='192.168.37.30:/vol/em_sourcing_dbf/em_sourcing_dbf'
mount_to_snap[13]='192.168.37.30:/vol/em_geoloc_dbf/em_geoloc_dbf'
mount_to_snap[14]='192.168.37.30:/vol/em_passerelle_dbf/em_passerelle_dbf'

nombre_de_montages=14

#Répertoires temporaires (pas utile pour l'instant):
temp_dir='192.168.37.31:/vol/em_sourcing_temp/em_sourcing_temp'

#Répertoire des archives log :
arch_log_dir='192.168.37.30:/vol/em_tools_arch/em_tools_arch'

#Répertoire des redolog :
redo_dir='192.168.37.30:/vol/em_tools_redo/em_tools_redo'

#Répertoire Flash :
flash_dir='192.168.37.31:/vol/em_tools_flash/em_tools_flash'

#Répertoire OCR :
ocr_dir='192.168.37.31:/vol/em_tools_ocr/em_tools_ocr'

#Répertoire VOTE :
vote_dir='192.168.37.31:/vol/em_tools_vote/em_tools_vote'
vote_path=/data/oradata/RAC/VOTE

#Répertoire udump
udump_dir=/opt/oracle/product/10.2/admin/ATOOLS/udump/

#emplacement spfile:
spfile_path=/data/oradata/EM_SOURCING/DBF/ATOOLS/spfileATOOLS.ora

####################
#Partie Oracle     #
####################


ORACLE_SID=ATOOLS1
NLS_LANG=FRENCH_FRANCE.AL32UTF8
LD_LIBRARY_PATH=/opt/oracle/oracle/product/10.2.0/db_1/lib:/lib:/usr/lib:/usr/local/lib
ORACLE_HOME=/opt/oracle/oracle/product/10.2.0/db_1
PATH=$PATH:/opt/oracle/oracle/product/10.2.0/db_1/bin

#Utilisateur netapp :
user_dbasnap=oracle
EMAIL=polebdd@fotovista.com

#############################################################################################################
#Fin de la partie a modifiée.                                                                               #
#############################################################################################################
export ORACLE_SID
export NLS_LANG
export LD_LIBRARY_PATH
export ORACLE_HOME
export PATH

sqlplus_bin=`/usr/bin/which sqlplus`
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

resto_base=resto_base
date_bck=`date +%H`
date_ctrl=`date +%Y-%m-%d-%H`
temp_file=/tmp/tempfile.lst
#############################################################################################################
#Fonctions snap,delete old snap  hotbackup, begin backup ...		               			    #
#############################################################################################################

#snapshot des montages

snapshot_montage(){
for i in `seq 1 ${nombre_de_montages}`
	do 
		ip_netapp=`echo ${mount_to_snap[${i}]} | awk -F : {'print $1'}`
		snap_name=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
		snap_to_do=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
		snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
		echo "snap delete ${snap_name} $snap_to_do_date"
		ssh ${user_dbasnap}@$ip_netapp snap delete ${snap_name} $snap_to_do_date
		echo "snap create ${snap_name} $snap_to_do_date"
		ssh ${user_dbasnap}@$ip_netapp snap create ${snap_name} $snap_to_do_date
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
                ip_netapp=`echo ${redo_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${redo_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${redo_dir} |  awk -F / '{print $NF}'`
                snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
		echo "${user_dbasnap}@$ip_netapp snap delete ${snap_name} $snap_to_do_date"
                ssh ${user_dbasnap}@$ip_netapp snap delete ${snap_name} $snap_to_do_date
		echo "snap create ${snap_name} $snap_to_do_date"
                ssh ${user_dbasnap}@$ip_netapp snap create ${snap_name} $snap_to_do_date
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
crontrol_to_save=`ls -lrt ${udump_dir} |  tail -1 | awk {'print $8'}`
cp -p ${udump_dir}/${crontrol_to_save} ${rep_arch}/crontrol_to_trace_${date_ctrl}

}


#sauvegarde crontrole file apres backup
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
                ip_netapp=`echo ${arch_log_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${arch_log_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${arch_log_dir} |  awk -F / '{print $NF}'`
                snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
		echo "snap delete ${snap_name} $snap_to_do_date"
                ssh ${user_dbasnap}@$ip_netapp snap delete ${snap_name} $snap_to_do_date
		echo "snap create ${snap_name} $snap_to_do_date"
                ssh ${user_dbasnap}@$ip_netapp snap create ${snap_name} $snap_to_do_date
}

#Purge des fichiers obselete :
purge_finale(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

rm ${rep_arch}/crontrol_to_trace_${date_ctrl}
rm ${rep_arch}/control01.ctl_apres_${date_ctrl}
rm ${rep_arch}/spfile_${date_ctrl}
rm ${rep_arch}/${resto_base}
rm ${rep_arch}/voting_disk_file_${date_ctrl}

}

#Création du fichier de restauration :
create_restau_file(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

path_resto_base=${rep_arch}/${resto_base}
rm ${path_resto_base}

echo "### restauration des dbs" >> ${path_resto_base}
for i in `seq 1 ${nombre_de_montages}`
        do
                ip_netapp=`echo ${mount_to_snap[${i}]} | awk -F : {'print $1'}`
                snap_name=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${mount_to_snap[${i}]} |  awk -F / '{print $NF}'`
                snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
                echo "ssh ${user_dbasnap}@$ip_netapp snap restore -s ${snap_to_do_date} ${snap_name}" >> ${path_resto_base}
done

echo "### restauration des redo" >> ${path_resto_base}
		ip_netapp=`echo ${redo_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${redo_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${redo_dir} |  awk -F / '{print $NF}'`
                snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
                echo "ssh ${user_dbasnap}@$ip_netapp snap restore -s ${snap_to_do_date} ${snap_name}" >> ${path_resto_base}

echo "### restauration des fichiers archives log" >> ${path_resto_base}
		ip_netapp=`echo ${arch_log_dir}  | awk -F : {'print $1'}`
                snap_name=`echo ${arch_log_dir}  |  awk -F / '{print $NF}'`
                snap_to_do=`echo ${arch_log_dir} |  awk -F / '{print $NF}'`
                snap_to_do_date=`echo ${snap_to_do}_${date_bck} | sed s/\ //`
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
echo "cp control01.ctl_apres_${date_ctrl} ${ligne}" >> ${path_resto_base}
done < ${spool_redo_log_resto} 

}

#Sauvegarde_spfile
sauvegarde_spfile(){
cat /etc/fstab | grep "192." | awk {'print $1" " $2'} > ${verif_datafile}
rep_arch=`cat ${verif_datafile} | grep ${arch_log_dir}  | awk {'print $2'}`

if [ -e ${spfile_path} ]
	then 
		cp ${spfile_path} ${rep_arch}/spfile_${date_ctrl}
	else 
		echo "ca pue"
		ft_mail
fi
}

#Sauvegarde ocr

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

ft_mail(){
mail -s "Hotbackup ${ORACLE_SID} en erreur !!! " $EMAIL << END
.
END
}

#############################################################################################################
#Execution du backup 											    #
#############################################################################################################

create_restau_file
verification_dbf
verification_redo
exit

sauve_txt_ctrl_file
begin_backup
snapshot_montage
end_backup
sauve_ctl_apres_bck
switch_redo
sauve_redo
sauvegarde_spfile
sauve_arch_log
sauvegarde_voting

purge_finale
