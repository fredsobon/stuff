#!/usr/bin/ksh

#===============================================================================
# @(#) Fichier:    prodDiagnostic.sh     
# @(#)
# @(#) Fonction:   
# @(#) Usage:           
# @(#)             
# @(#)
#===============================================================================
# @(#)
# @(#) Creation:        1.0 
# @(#) Modification     2.0



# Author: Gilles Creantor
# Last modified by: David Larquey

# This script reports applicative user logon informations using ASH for the specified date interval
# Just user logons for specified schemas are reported (see listeSchemas)
# This script must run under ORATOOLX, because it needs a TNS connexion to access to the database
# This script asks for: the user, password, and the database to audit


# Time (in days) during we audit users access
AUDIT_INTERVAL=3

# -------------------------
# Fonction traitement principale
# -------------------------
function traite {
    BASE=$1
    SELECTION=$2
    
    CRITERE_SCHEMA=`listeSchemas | awk "(\\$2==\\"$SELECTION\\") {print \\$1}" | xargs | sed "s/ /','/g"`
    CRITERE_SCHEMA="'$CRITERE_SCHEMA'"

    REQ="
select distinct b.username||';'||a.program||';'||A.MACHINE||';'||A.SAMPLE_TIME full, b.username,A.SAMPLE_TIME, count(*) over (partition by b.username) count
--select distinct count(b.username) over (partition by b.username)||';'||b.username||';'||a.program||';'||A.MACHINE||';'||A.SAMPLE_TIME
from dba_hist_active_sess_history a, dba_users b
where (program not like ('oracle@%') and program not like ('sqlr-%'))
--where (program not like ('dev.exe')
--or program like ('%sqlplus%')
--or program like ('SQL*Plus')
--or upper(program) like ('TOAD%')
--or program like ('SQL Developer')
--or program like ('PL/SQL Developer')
--or program like ('OEM'))
and A.USER_ID=B.USER_ID
and sample_time<sysdate
and sample_time>sysdate-$ARG_AUDIT_INTERVAL
and session_type='FOREGROUND'
and b.username in ($CRITERE_SCHEMA)
order by b.username,A.SAMPLE_TIME;
"


    # Especially for ASAP database (Column MACHINE  is unknown on 10.2.0.1)
    [ "$SELECTION" = "ASAP" ] && REQ="
select distinct b.username||';'||a.program||';'||'UNKNOWN'||';'||A.SAMPLE_TIME full, b.username,A.SAMPLE_TIME, count(*) over (partition by b.username) count
--select distinct b.username,a.program, 'UNKNOWN' MACHINE,A.SAMPLE_TIME
from dba_hist_active_sess_history a, dba_users b
where (program not like ('oracle@%') and program not like ('sqlr-%'))
--where (program not like ('dev.exe')
--or program like ('%sqlplus%')
--or program like ('SQL*Plus')
--or upper(program) like ('TOAD%')
--or program like ('SQL Developer')
--or program like ('PL/SQL Developer')
--or program like ('OEM'))
and A.USER_ID=B.USER_ID
and sample_time<sysdate
and sample_time>sysdate-$ARG_AUDIT_INTERVAL
and session_type='FOREGROUND'
and b.username in ($CRITERE_SCHEMA)
order by b.username,A.SAMPLE_TIME;
"

    echo "=> Executing SQL request : $REQ"

    sqlplus -s /nolog << END_TRAITE 1> /dev/null 2>&1
  whenever sqlerror exit failure;
  whenever oserror exit failure;
  set serveroutput on size 1000000 
  spool $TMPFILE
  
  conn $DBA_USER/$DBA_PASSWD@$BASE
  set pagesize 0
  set feedback off
  set heading off
  set echo off
  set lines 180
set colsep ';'
  col username format a20
  col program format a40
  col MACHINE format a20
  col SAMPLE_TIME format a25
col full format a110

$REQ

  spool off

END_TRAITE

    [ $? -ne 0 ] && {
        AffMess ERR "---   Echec du traitement."
        cat ${TMPFILE} >>$LOGFILE
        ExitScript ERR
    }

    cat ${TMPFILE} >>$LOGFILE
    echo "" >>$LOGFILE
}

# -------------------------
# Fonction liste des schemas
# -------------------------
# Whitelist for all schemas
function listeSchemas {
    echo "
ACCOUNTINGIN    oraacc1p
ACCOUNTINGOUT   oraacc1p
ACCOUNTRECEIVE  oraacc1p
ADMIN   orabrn1p
ADMIN   oratlb1p
ADMIN   oraord1p
ADMIN   orappl1p
ADMIN_BI_RW oraord1p
ADMIN_CAISSE_RO orabrn1p
ADMIN_MIRROR    oraorm1p
ADMINAPPLI  oraacc1p
AFFIL   oratla1p
AGILEO  orakim1p
ALEX    orapay1p
ALIM_FEP    oraord1p
APACHE_1_58 oraorm1p
APC orafrt1p
ASAP    orabrn1p
ASTRID  orapay1p
AUDREY  orapay1p
AURANE  orapay1p
AUTOMAILER  orafrt1p
AZIZA   orapay1p
BACKOFF orabrn1p
BACKUP_SCHEMAS  oratlb1p
BCHECK  oraord1p
BI_ADMIN    oraorm1p
BIDWH   orabrn1p
BIDWH   oraorm1p
BIPIXPLACE  orappl1p
BO_EPTICA   oratlb1p
BO_MAILING_USER oraorm1p
BOCLIENT    oratlb1p
BODET   orakel1p
BOREAD  oraorm1p
BOREAD  orappl1p
BR_CURRYS   orafrt1p
BR_DIXONS   orafrt1p
BR_PCWORLD  orafrt1p
BR_PIX  orafrt1p
BR_PIXPRO   orafrt1p
BRAIN   oracas1p
BRAIN_MDR   orabrn1p
BRAIN_TRAFFIC_RO    orabrn1p
BRAINAUDIT  orabrn1p
BRAINDSG    orabrn1p
BRAINPIX    orabrn1p
BUCHTA  oraorm1p
BUSICAISSE  orabrn1p
CARREFOUR   orafrt1p
CASH    oraacc1p
CCMX    orapay1p
CELIO   orafrt1p
CENTRAL oracas1p
CHECKDBA    orappl1p
COMPTA  orabrn1p
COMPTAINF   oracas1p
COMPTASCRIPT    oraacc1p
CONFIGURATION   oraacc1p
CORALIE orapay1p
CRON_CARREFOUR  orafrt1p
DAVENAT orapay1p
DEVPIXPLACE oraord1p
DEVPIXPLACE orappl1p
DROPSHIPMENT    orabrn1p
DROPSHIPMENT    orafrt1p
DSGCURRYS   orafrt1p
DSGCURRYSNG orafrt1p
DSGDIXONS   orafrt1p
DSGDIXONSNG orafrt1p
DSGPCWORLD  orafrt1p
DSGPCWORLDNG    orafrt1p
EM_CLIENT   orarfrt1p
EM_FEEDS    oratla1p
EM_ORDER    oraord1p
EMGC    oraemg1p
EPTICA  oraept1p
EPTICA_INFO oraept1p
ETL oraacc1p
EXPORT_READ orabrn1p
EXTERNAL_CONTENT    orabrn1p
FLORIANE    orapay1p
FOCI    oracas1p
FOTOVISTA   oracas1p
FOTOVISTA   orakim1p
FRAUDBUSTER oratlb1p
GAPI    oratla1p
GATEWAYDSG  oratlb1p
GEOLOC  oratlb1p
GLOUTON_RO  oraord1p
GLOUTON_RW  oraord1p
IKRAME  orapay1p
INGRID  orapay1p
INGRIDV orapay1p
INTEGEM oraord1p
ISABELLE    orapay1p
JAPAN   oracas1p
JAPAN   orafrt1p
JOELLE  orapay1p
JONAS   orapay1p
LASERFOT    oracas1p
LOAD_RELAY  oratlb1p
LOAD_RELAY  oraord1p
LOG oraacc1p
LOGISTIQ    orabrn1p
LOGISTIQUE  oratlb1p
LOGISTIQUE  oracas1p
MAIL_1_30   oraorm1p
MAILING oratla1p
MGMT_VIEW   oraacc1p
MGMT_VIEW   oraept1p
MONNIER orafrt1p
MVPLACE orappl1p
NETLOAD orabrn1p
NETLOAD orafrt1p
NETTOYAGE   orappl1p
NEWARCHI_GLOUTON    oraord1p
OLIVIA  orapay1p
OLIVIER orapay1p
ORASCUD oratlb1p
ORDERCOMPTA oraacc1p
OURY    orapay1p
OUTLN   orakim1p
PASSERELLE  oratla1p
PIX orafrt1p
PIXBDD_1_102    oraorp1p
PIXPHOTO_2_107  oraorm1p
PIXMANIA    orafrt1p
PIXPRO  orafrt1p
PIXPRO_1_151    oraorm1p
PIXPRO_1_151    oraorp1p
POLE_GW oratla1p
PROD    oraacc1p
READER_USER oraorm1p
REPORTING   orakim1p
RHJS    orapor1p
RHPLACE orapay1p
RHPLACE orapor1p
RMANCAT oraref1p
SAV2    oracas1p
SCOTT   orapay1p
SENTINEL    orasnt1p
SHOPBOT oratla1p
SHOPBOT_ENGINE  oratla1p
SHOPBOT_OCI_BRAIN   orabrn1p
SHOPBOT_OCI_PPLACE  orappl1p
SI_INFORMTN_SCHEMA  oraacc1p
SNIPER  oratla1p
SOE orafrt1p
SOPHIE  orapay1p
SOURCES_1_66    oraorm1p
SOURCING    oratla1p
SPECIAL_OPS oraacc1p
STRMADMIN   orabrn1p
SYNCHRO oratla1p
TALEND  orabrn1p
TALEND  oraord1p
TEMP_SCHEMA orabrn1p
TEST    orapay1p
THIERRY orapay1p
TRANSLATIONS    orafrt1p
UPORTAIL    orapay1p
USER_APP_BRAIN_POLEGW   orabrn1p
USER_BI oratla1p
USER_BI oraacc1p
USER_BI orabrn1p
USER_BI oratlb1p
USER_BI oraord1p
USER_BI orafrt1p
USER_DEBUG  oraacc1p
USER_SAV    oratlb1p
USER_TEMP   orappl1p
VMBRAIN orabrn1p
VMCDE   oraord1p
VMCOMPTA    oraacc1p
VMFRONT orafrt1p
VMFRONT_BIS orabrn1p
VMFRONT_BIS orafrt1p
VMTOOLS oratla1p
VMTOOLS oratlb1p
WEB_SERV_BRAIN  orabrn1p
WNG oratlb1p
BODET   KELIO
RHJS    PORTAIL
RHPLACE PORTAIL
CCMX PAYE
DIP PAYE
MGMT_VIEW PAYE
THIERRY PAYE
CEGID PAYE
UPORTAIL PAYE
DAVENAT PAYE
DAMIEN PAYE
AZIZA PAYE
BARBARA PAYE
INGRIDV PAYE
SUPPORT PAYE
ASTRID PAYE
ANDRE PAYE
RHPLACE PAYE
JOELLE PAYE
AICHA PAYE
SARAH PAYE
FOTOVISTA KIMOCE
AGILEO  KIMOCE
FOTOVISTA ASAP
ASAP ASAP
AGILEO ASAP
"
}

# -------------------------
# Fonction Saisie infos dba
# -------------------------
function saisieInfoDBA {
    echo -n "Saisir le compte oracle dba ? "
    read DBA_USER
    echo -n "Saisir le mot de passe du compte oracle dba ? "
    read DBA_PASSWD
    echo -n "Saisir la Base ? (ALL) "
    read ARG_BASE
    [ -z "$ARG_BASE" ] && ARG_BASE='ALL'
    
    ([ -z "$DBA_USER" ] || [ -z "$DBA_PASSWD" ] || [ -z "$ARG_BASE" ]) && { echo "Wrong value"; exit 1; }

    echo -n "Saisir la duree d'audit ($AUDIT_INTERVAL jours) : "
    read ARG_AUDIT_INTERVAL
    [ -z "$ARG_AUDIT_INTERVAL" ] && ARG_AUDIT_INTERVAL=$AUDIT_INTERVAL
    echo $ARG_AUDIT_INTERVAL|egrep -q '^[0-9]+$' || { echo "Wrong interval"; exit 1; }
}


# -------------------------
# Fonction sortie du script
# -------------------------
function ExitScript {
    [ -f ${TMPFILE} ] && rm -f ${TMPFILE}

    echo "See Output file: $LOGFILE"

    case $1 in
    INF*) AffMess INF "FIN ${SCRIPT}"
          exit 0
          ;;
    WRN*) AffMess WRN "FIN ${SCRIPT}"
          exit 2
          ;;
    ERR*) AffMess ERR "FIN ${SCRIPT}"
          exit 1
          ;;
       *) AffMess INF "FIN ${SCRIPT}"
          exit 0
          ;;
  esac
}

# -------------------------
# Fonction envoi de message
# -------------------------
function AffMess {
  DATE=`date +'%d/%m/%y %H:%M:%S'`
  case $1 in
    INF*) echo "=INF= $DATE $2" | tee -a $LOGFILE;;
    WRN*) echo "=WRN= $DATE $2" | tee -a $LOGFILE;;
    ERR*) echo "=ERR= $DATE $2" | tee -a $LOGFILE;;
       *) echo "=xxx= $DATE $2" | tee -a $LOGFILE;;
  esac
}



##############
#### MAIN ####
##############

SCRIPT=`basename $0`

REPTMP=/tmp
REPLOG=/tmp

HOROD=`date +'%Y%m%d%H%M%S'`
LOGFILE=$REPLOG/${SCRIPT}_`whoami`.${HOROD}.$$.log
> $LOGFILE

TMPFILE=$REPTMP/${SCRIPT}_${HOROD}.$$.tmp
>$TMPFILE

trap ExitScript EXIT


# List all databases
D=(ATOOLS BRAINPIX BTOOLS CAISSE COMPTA FRONT ORDER PPLACE KELIO KIMOCE PORTAIL PAYE ASAP)
B=(oratla1p orabrn1p oratlb1p oracas1p oraacc1p orafrt1p oraord1p orappl1p KELIO KIMOCE PORTAIL PAYE ASAP)
T=(PROD_ATOOLS PROD_BRAINPIX PROD_BTOOLS PROD_CAISSE PROD_BOCOMPTA PROD_FRONT PROD_COMMANDE PROD_PPLACE PROD_KELIO PROD_KIMOCE PROD_PORTAIL PROD_PROD PROD_ASAP)

echo "This script extracts all logon informations for a database"
echo -e "\nAvailable databases: ${B[@]}\n"

saisieInfoDBA

n=${#B[@]}
[ ${#D[@]} -ne ${#B[@]} -o ${#D[@]} -ne ${#T[@]} ] && { echo "Invalid description"; exit 1; }


for i in $(seq 0 $((n-1))); do
    if [ "$ARG_BASE" = "ALL" -o "$ARG_BASE" = "${B[$i]}" ]; then
        echo "# Base ${D[$i]}"
        AffMess INF "Base ${D[$i]}"
        traite "${T[$i]}" "${B[$i]}"
    fi
done


#AffMess INF "Base ATOOLS"
#traite "PROD_ATOOLS" "oratla1p"
#
#AffMess INF "Base BRAINPIX"
#traite "PROD_BRAINPIX" "orabrn1p" 
#
#AffMess INF "Base BTOOLS"
#traite "PROD_BTOOLS" "oratlb1p" 
#
#AffMess INF "Base CAISSE"
#traite "PROD_CAISSE" "oracas1p" 
#
#AffMess INF "Base COMPTA"
#traite "PROD_BOCOMPTA" "oraacc1p" 
#
#AffMess INF "Base FRONT"
#traite "PROD_FRONT" "orafrt1p" 
#
#AffMess INF "Base ORDER"
#traite "PROD_COMMANDE" "oraord1p" 
#
#AffMess INF "Base PPLACE"
#traite "PROD_PPLACE" "orappl1p" 

# AffMess INF "Base KELIO"
# traite "PROD_KELIO" "KELIO"
# 
# AffMess INF "Base KIMOCE"
# traite "PROD_KIMOCE" "KIMOCE"
# 
# AffMess INF "Base PORTAIL"
# traite "PROD_PORTAIL" "PORTAIL"
# 
# AffMess INF "Base PAYE"
# traite "PROD_PROD" "PAYE"

#AffMess INF "Base ASAP"
#traite "PROD_ASAP" "ASAP"

ExitScript INF

# vim: set sw=4 et ts=4
