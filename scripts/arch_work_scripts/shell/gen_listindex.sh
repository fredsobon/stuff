#!/bin/bash
#set -x
##########################
# Deplacement des index :
##########################

#file="/home/oracle/adminbdd/reorgindex/tablespace_JAPAN_IDX.log"
#file="/home/oracle/adminbdd/reorgindex/tablespace_JAPAN_IDX.log"

file=$1


xs_file="my_xs.sql"
ss_file="my_ss.sql"
mm_file="my_mm.sql"
ml_file="my_ml.sql"
ll_file="my_ll.sql"
xl_file="my_xl.sql"

#Initialisation des fichiers
echo "" > $xs_file
echo "" > $ss_file
echo "" > $mm_file
echo "" > $ml_file
echo "" > $ll_file
echo "" > $xl_file


while read line 
do
	idx=`echo ${line} | awk {'print $1'}`
	hwm=`echo ${line} | awk {'print $4'}`
	#echo  "${idx}.................${hwm}"
        WATER=`echo $hwm | bc`		
	if [ $hwm -lt 1024 ]
	then
		echo  "${idx}.................${hwm}.................XS"
		echo " alter index $idx nologging; 				             " >> $xs_file
		echo " alter index $idx rebuild tablespace TBS_IDX_XS01                          " >> $xs_file
		echo " storage (initial 16K next 16K maxextents unlimited pctincrease 0);    " >> $xs_file
		echo " alter index $idx logging;  				             " >> $xs_file
		echo " analyze index $idx estimate statistics sample 20 percent;             " >> $xs_file
		echo " commit; " >> $xs_file
		echo " " >> $xs_file
	
	fi
	
	if  [ $hwm -ge 1024  ] && [ $hwm -lt 24000  ]
	then
		echo "${idx}.................${hwm}.................SS"
                echo " alter index $idx nologging;                                            " >> $ss_file
                echo " alter index $idx rebuild tablespace TBS_IDX_SS01                           " >> $ss_file
                echo " storage (initial 392K next 392K maxextents unlimited pctincrease 0);   " >> $ss_file
                echo " alter index $idx logging;                                              " >> $ss_file
                echo " analyze index $idx estimate statistics sample 20 percent;              " >> $ss_file
                echo " commit; " >> $ss_file
		echo " " >> $ss_file
	fi

        if [ $hwm -ge 24000  ] && [ $hwm -lt 200000  ]
        then
                echo "${idx}.................${hwm}.................MM"
                echo " alter index $idx nologging;                                            " >> $mm_file
                echo " alter index $idx rebuild tablespace TBS_IDX_MM01                           " >> $mm_file
                echo " storage (initial 8928K next 8928K maxextents unlimited pctincrease 0); " >> $mm_file
                echo " alter index $idx logging;                                              " >> $mm_file
                echo " analyze index $idx estimate statistics sample 20 percent;              " >> $mm_file
                echo " commit; " >> $mm_file
		echo " " >> $mm_file

        fi

        if [ $hwm -ge 200000  ] && [ $hwm -lt 1024000  ]
        then
                echo "${idx}.................${hwm}.................ML"
                echo " alter index $idx nologging;                                              " >> $ml_file
                echo " alter index $idx rebuild tablespace TBS_IDX_ML01                             " >> $ml_file
                echo " storage (initial 44624K next 44624K maxextents unlimited pctincrease 0); " >> $ml_file
                echo " alter index $idx logging;                                                " >> $ml_file
                echo " analyze index $idx estimate statistics sample 20 percent;                " >> $ml_file
                echo " commit; " >> $ml_file
		echo " " >> $ml_file

        fi

        if [ $hwm -ge 1024000  ] && [ $hwm -lt 24000000  ]
        then
                echo "${idx}.................${hwm}.................LL"
                echo " alter index $idx nologging;                                                " >> $ll_file
                echo " alter index $idx rebuild tablespace TBS_IDX_LL01                           " >> $ll_file
                echo " storage (initial 190648K next 190648K maxextents unlimited pctincrease 0); " >> $ll_file
                echo " alter index $idx logging;                                                  " >> $ll_file
                echo " analyze index $idx estimate statistics sample 20 percent;                  " >> $ll_file
                echo " commit; " >> $ll_file
		echo " " >> $ll_file

        fi


        if [ $hwm -ge 24000000  ] 
        then
                echo "${idx}.................${hwm}.................XL"
                echo " alter index $idx nologging;                                                " >> $xl_file
                echo " alter index $idx rebuild tablespace TBS_IDX_XL01                           " >> $xl_file
                echo " storage (initial 190648K next 190648K maxextents unlimited pctincrease 0); " >> $xl_file
                echo " alter index $idx logging;                                                  " >> $xl_file
                echo " analyze index $idx estimate statistics sample 20 percent;                  " >> $xl_file
                echo " commit; " >> $xl_file
                echo " " >> $xl_file
        fi
#sleep 1  
done < ${file}

