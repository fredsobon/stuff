export ORACLE_HOME=/opt/oracle/product/10.2.0.5/db_1
export ORACLE_SID=oratla2p

##################################################################################################
function get_database_role
{
echo "set head off
col thread for 9
col sequence for 999999
select THREAD# as thread , max(SEQUENCE#) as sequence from v\$archived_log
where applied='YES'
GROUP BY THREAD#;"|$ORACLE_HOME/bin/sqlplus -s / as sysdba
return
}

LAST_APPLIED=$(get_database_role)

THREAD_1=$(echo $LAST_APPLIED | awk '{print $1}')
THREAD_2=$(echo $LAST_APPLIED | awk '{print $3}')
SEQ_1=$(echo $LAST_APPLIED | awk '{print $2}')
SEQ_2=$(echo $LAST_APPLIED | awk '{print $4}')

FILE_PREFIX=oratla2p_
FILE_SUFFIX=_660248236.arc

ARCH_DEST="/data/oradata/oratla2p/arc/"
ARCH_DEST_BIS="/data/oradata/oratla2p/arc/stdby/"
sequence=${SEQ_1}
applied_log=$ARCH_DEST"oratla2p_${THREAD_1}_${sequence}_660248236.arc"
applied_log_bis=$ARCH_DEST_BIS"oratla2p_${THREAD_1}_${sequence}_660248236.arc"
while [ -e ${applied_log} -o -e ${applied_log_bis} ]; do
	if [ -e ${applied_log} ]; then
		#echo "${applied_log} to delete .."
		echo "rm ${applied_log}"
		rm ${applied_log}
	fi
	if [ -e ${applied_log_bis} ]; then
		#echo "${applied_log_bis} to delete .."
		echo "rm ${applied_log_bis}"
		rm ${applied_log_bis}
	fi
	sequence=$(expr ${sequence} - 1 )
	applied_log=$ARCH_DEST"oratla2p_${THREAD_1}_${sequence}_660248236.arc"
	applied_log_bis=$ARCH_DEST_BIS"oratla2p_${THREAD_1}_${sequence}_660248236.arc"
	if [ ! -e ${applied_log} -a ! -e ${applied_log_bis} ]; then
		echo "${applied_log} inexistant ."
	fi
done

sequence=${SEQ_2}
applied_log=$ARCH_DEST"oratla2p_${THREAD_2}_${sequence}_660248236.arc"
applied_log_bis=$ARCH_DEST_BIS"oratla2p_${THREAD_2}_${sequence}_660248236.arc"
while [ -e ${applied_log} -o -e ${applied_log_bis} ]; do
        if [ -e ${applied_log} ]; then
                #echo "${applied_log} to delete .."
                echo "rm ${applied_log}"
		rm ${applied_log}
        fi
        if [ -e ${applied_log_bis} ]; then
                #echo "${applied_log_bis} to delete .."
                echo "rm ${applied_log_bis}"
		rm ${applied_log_bis}
        fi
        sequence=$(expr ${sequence} - 1 )
        applied_log=$ARCH_DEST"oratla2p_${THREAD_2}_${sequence}_660248236.arc"
        applied_log_bis=$ARCH_DEST_BIS"oratla2p_${THREAD_2}_${sequence}_660248236.arc"
        if [ ! -e ${applied_log} -a ! -e ${applied_log_bis} ]; then
                echo "${applied_log} inexistant ."
        fi
done
