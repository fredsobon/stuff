#!/bin/bash
#set -x

if [ "$1" != "" ] 
then
  export ORACLE_SID=$1
elif [ "$ORACLE_SID" != "" ] 
then
  export ORACLE_SID=$ORACLE_SID
fi
export ORACLE_HOME=/opt/oracle/product/10.2.0.5/db_1
#export ORAENV_ASK=NO

#. oraenv > /dev/null 2>&1
export ORACLE_HOME=/opt/oracle/product/10.2.0.5/db_1
export PATH=$ORACLE_HOME/bin:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$ORACLE_HOME/lib32:$LD_LIBRARY_PATH

GGDIR=""
ERR=0
LAGMAX=4
DATETIME=`date +'%Y%m%d%H%M%S'`
TRC_FIC=/tmp/${DATETIME}_check_gg_$ORACLE_SID
TRC_LAG=/tmp/${DATETIME}_check_gg_lag_$ORACLE_SID
RECIPIENT_MAIL="g.creantor@pixmania-group.com gg_split_monitoring@pixmania-group.com s.blanc@pixmania-group.com h.touarigt@pixmania-group.com eugene.ebara@easyteam.fr"
#RECIPIENT_MAIL="s.blanc@pixmania-group.com"


case $ORACLE_SID in
    orafrt1p*) export GGDIR=/data/export/front/ggs;;
    orabrn1p*) export GGDIR=/data/export/brain/ggs;;
    oraord1p*) export GGDIR=/data/export/order/ggs;;
    oratla1p*) export GGDIR=/data/export/atools/ggs;;
    oratlb1p*) export GGDIR=/data/export/btools/ggs ;;
    orappl1p*) export GGDIR=/data/export/pplace/ggs;;
       *) echo "$ORACLE_SID:Unknown database" > $TRC_FIC
          ERR=-1
       ;;
esac

if [ "$GGDIR" != "" ] && [ -d $GGDIR ]
then
  cd $GGDIR
./ggsci > ${TRC_FIC} <<EOF
info *
EOF

  cd $GGDIR
./ggsci > ${TRC_LAG} <<EOF
info all
EOF


  cat ${TRC_LAG}| egrep -E "^E|^R" | awk '{ print $4 }' | awk -F: '{ print $1 }' | while read LAG ;
  do
    echo $LAG
    if [ $LAG -ge $LAGMAX ];
    then
      echo $LAG >> /tmp/laggg
    fi
  done

  if [ -f /tmp/laggg ];
  then
    rm /tmp/laggg
    LAG=1
  else
    LAG=0
  fi

  ERR=`grep Status ${TRC_FIC} | grep -v RUNNING | wc -l`
else
  echo "Cannot find directory $GGDIR">${TRC_FIC}
  ERR=-1
fi

if [ $ERR -ne 0 ];
then
 for recip in $RECIPIENT_MAIL
 do
 mailx -s "failure detected on $ORACLE_SID"  $recip < ${TRC_FIC}
 done
 exit 1
else
  if [ $LAG -eq 1 ];
  then
    for recip in $RECIPIENT_MAIL
    do
    mailx -s "lag over than $LAGMAX hours detected on $ORACLE_SID"  $recip < ${TRC_LAG}
    done
    exit 1
  fi
fi

rm -f ${TRC_FIC}
rm -f ${TRC_LAG}