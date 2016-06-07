#!/bin/bash

HOSTS=hosts
HOSTSBAK=hosts.back
DISTRIB=distrib.conf
MVS=mvs.conf
BACKDIST=/mcorp/backup/distrib/
BACKDIR=/mcorp/backup/hosts/
BACKMVS=/mcorp/backup/mvs/
FILE=/etc/hosts
WAY=/ilius/etc/
SSH_OPT="-o PasswordAuthentication=no -o stricthostkeychecking=no -o ForwardAgent=no -o ConnectTimeout=10"
#----------------------------------------------------------------------------------------------------------
EDITOR=/usr/bin/vim
#----------------------------------------------------------------------------------------------------------
ADR_EMAIL="exploit@meetic-corp.com"
#----------------------------------------------------------------------------------------------------------
echo "---------------------"
echo "| 1 - fichier hosts |"
echo "| 2 - distrib.conf  |"
echo "| 3 - mvs.conf      |"
echo "---------------------"
echo ""
echo "Taper Q pour quiter"
echo ""
echo -n "Quel fichier voulez vous editer ? [1,2,3,Q]"
read RESPONSE

#----------------------------------------SECTION FICHIER HOSTS---------------------------------------------

if [ "$RESPONSE" = "1" ] 
then
	SAVE=${HOSTS}.`date +%Y%m%d%H%M`
	TMP=/tmp/${HOSTS}.tmp
	
	TEST=`diff ${BACKDIR}${HOSTSBAK} ${FILE}`
	if  [ $? -ne 0 ]
	then
		echo ""
	        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
		echo ""
		echo "PRECEDEMENT LE FICHIER A ETE EDITER SANS LE SECURMOD"
		echo ""
		echo "----------------------"
        	echo "| > element supprime |"
        	echo "| < element ajoute   |"
        	echo "----------------------"
		echo "${TEST}"
		echo ""
		echo "Appuyer une touche pour continuer..."
		read

		echo -e "PRECEDEMENT LE FICHIER A ETE EDITER SANS LE SECURMOD\n\n ----------------------\n| > element supprime |\n| < element ajoute   |\n----------------------\n ${TEST}" | mail -s "Modification sans SECURMOD du fichier HOSTS" ${ADR_EMAIL}
	fi

	cp ${FILE} ${TMP}
	${EDITOR} ${TMP}
	
	echo ""
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo ""
	DIFF=`diff ${TMP} ${FILE}`
	
	if  [ $? -ne 1 ]
	then
		echo "PAS DE MODIFICATION DU FICHIER"
		rm -f ${TMP}
		echo -n "Voulez vous simplement synchroniser le hosts ? [y,N]"
                read RESPONSE
                if [ "$RESPONSE" = "y" ]
                then
			for i in `distrib list -g self`
			do
				scp ${SSH_OPT} /etc/hosts ${i}:/etc/
			done
			scp ${SSH_OPT} /etc/hosts puppet:/etc/
      		        /ilius/scripts/distrib sync -g sync-hosts /etc/hosts /
                        /mcorp/script/Exploit/synchro_host_to_avamar
                        echo ""
                        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
                	echo ""
                        echo "----------------------------------"
                        echo "| Le fichier a ete synchronise   |"
                        echo "----------------------------------"
			echo "Le fichier host a ete synchronise sans subir de modification" | mail -s "Synchronisation du fichier HOSTS" ${ADR_EMAIL}
                fi

	else
	echo "----------------------"
        echo "| > element supprime |"
        echo "| < element ajoute   |"
        echo "----------------------"

	echo "${DIFF}"

	echo ""

        TMPIPDOUBLE=$(mktemp -q /tmp/nombre_ip_double_after_XXXXXX)
        #sed 's/^[ \t]*\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)[ \t][ \t]*.*$/\1/p;d' ${TMP} | grep -v 62.23.26 | egrep -v '10.120.100.2$' |  sort | uniq -c | grep  -v '^[ \t]*1[ \t]' > $TMPIPDOUBLE
        sed 's/^[ \t]*\([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\)[ \t][ \t]*.*$/\1/p;d' ${TMP} | egrep -v "62.23.26|10.120.100.2$" |  sort | uniq -c | grep  -v '^[ \t]*1[ \t]' > $TMPIPDOUBLE
        if [ -s $TMPIPDOUBLE  ]
        then
        	echo '/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\'
                echo "ATTENTION: il y a des ips en double"
                echo ""
		for i in $(cat ${TMPIPDOUBLE} | awk '{ print $2}');do fgrep ${i} ${TMP};done
                echo ""
                echo '/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\'
        fi

	echo -n "Voulez vous enregistrer ? [y,N]"
	read RESPONSE

		if [ "$RESPONSE" = "y" ]
		then
			cp ${FILE} ${BACKDIR}${SAVE}
			cp ${TMP} ${FILE}
			cp ${FILE} ${BACKDIR}${HOSTSBAK}
			RESULT=`ls ${BACKDIR} | wc -l`
	
				if [ "${RESULT}" -gt 100 ]
				then
					RESULT2=`ls ${BACKDIR} | head -1` 
					rm -f ${BACKDIR}${RESULT2}
					echo ""
				        echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        				echo ""
	        			echo "------------------------------------------------------------"
					echo "| Le fichier de sauvegarde ${RESULT2} a ete efface |" 
	        			echo "------------------------------------------------------------"
				fi

			rm -f ${TMP}
			echo ""
                	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	                echo ""
			echo "-----------------------------------"
			echo "| le fichier a ete edite et sauve |"
			echo "-----------------------------------"
			echo -e "----------------------\n| > element supprime |\n| < element ajoute   |\n----------------------\n ${DIFF}" | mail -s "Modification du fichier HOSTS" ${ADR_EMAIL}
			
			if [ -s $TMPIPDOUBLE  ]
	                then
				echo '/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\'
                    		echo ""
                    		echo "ATTENTION: IL Y A DES IPs EN DOUBLE"
				echo "LE FICHIER HOSTS A ETE ENREGISTRE "
                    		echo "Vueillez corriger votre nouvelle entree"
                    		echo "afin de pouvoir synchroniser le fichier HOSTS merci"
                    		echo ""
				for i in $(cat ${TMPIPDOUBLE} | awk '{ print $2}');do fgrep ${i} ${FILE};done
        	            	echo ""
				echo '/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\/!\'
				exit 0
			fi
			
			echo -n "Voulez vous synchroniser le hosts ? [y,N]"
			read RESPONSE
			if [ "$RESPONSE" = "y" ] 
			then
				/ilius/scripts/distrib sync -g self /etc/hosts /
				/ilius/scripts/distrib sync -g sync-hosts /etc/hosts /
				scp ${SSH_OPT} /etc/hosts puppet:/etc/
				/mcorp/script/Exploit/synchro_host_to_avamar

				# Push hosts file in puppet repository, to deploy on servers managed by Puppet
				cd /mcorp/data/puppet/profile/files
				git checkout production
				git pull &> /tmp/puppet-git-pull.log
				cp ${FILE} .
				git commit -a -m "/etc/hosts update" &> /tmp/puppet-git-comit.log
				git push origin production &> /tmp/puppet-git-push.log

				echo ""
        			echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        			echo ""
				echo "----------------------------------"
	        		echo "| Le fichier a ete synchronise   |"
        			echo "----------------------------------"
			fi

		else
			rm -f ${TMP}
			echo ""
	        	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
	        	echo ""
			echo "-----------------------------------------------"
			echo "| Le fichier a ete modifie mais pas enregistre|"
			echo "-----------------------------------------------"
			exit
		fi

	fi

fi

#----------------------------------------SECTION DU DISTRIB.CONF----------------------------------------------------------

if [ "$RESPONSE" = "2" ]
then
        SAVE=${DISTRIB}.`date +%Y%m%d%H%M`
        TMP=/tmp/${DISTRIB}.tmp
        cp ${WAY}${DISTRIB} ${TMP}
        ${EDITOR} ${TMP}
        
	echo ""
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo "----------------------"
        echo "| > element supprime |"
        echo "| < element ajoute   |"
        echo "----------------------"
        DIFF=`diff ${TMP} ${WAY}${DISTRIB}`
        echo "${DIFF}"

	echo ""
        echo -n "Voulez vous enregistrer ? [y,N]"
        read RESPONSE

        if [ "$RESPONSE" = "y" ]
        then
                cp ${WAY}${DISTRIB} ${BACKDIST}${SAVE}
                cp ${TMP} ${WAY}${DISTRIB}
                RESULT=`ls ${BACKDIST} | wc -l`

                        if [ "${RESULT}" -gt 50 ]
                        then
                                RESULT2=`ls ${BACKDIST} | head -1`
                                rm -f ${BACKDIST}${RESULT2}
				echo ""
        			echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        			echo ""
                                echo "------------------------------------------------------------"
                                echo "| Le fichier de sauvegarde ${RESULT2} a ete efface |" 
                                echo "------------------------------------------------------------"
                        fi

                rm -f ${TMP}
                echo ""
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
                echo ""
                echo "-----------------------------------"
                echo "| le fichier a ete edite et sauve |"
                echo "-----------------------------------"
                echo -e "----------------------\n| > element supprime |\n| < element ajoute   |\n----------------------\n ${DIFF}" | mail -s "Modification du DISTRIB.CONF" ${ADR_EMAIL}

                echo -n "Voulez vous synchroniser distrib.conf ? [y,N]"
                read RESPONSE
                if [ "$RESPONSE" = "y" ]
                then
			/mcorp/script/Exploit/dsh_convert.sh
                        /ilius/scripts/distrib sync -g self ${WAY}${DISTRIB} /
			ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no isync1 "/mcorp/script/Exploit/dsh_convert.sh"
                        echo ""
                	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
                	echo ""
			echo "----------------------------------"
                        echo "| Le fichier a ete synchronise   |"
                        echo "----------------------------------"
                fi

        else
                rm -f ${TMP}
                echo ""
                echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
                echo ""
                echo "----------------------------------"
                echo "| Le fichier n'a pas ete modifie |"
                echo "----------------------------------"
                exit
        fi
fi

#----------------------------------------SECTION DU MVS.CONF----------------------------------------------------------

if [ "$RESPONSE" = "3" ]
then
        SAVE=${MVS}.`date +%Y%m%d%H%M`
        TMP=/tmp/${MVS}.tmp
        cp ${WAY}${MVS} ${TMP}
        ${EDITOR} ${TMP}

        echo ""
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""
        echo "----------------------"
        echo "| > element supprime |"
        echo "| < element ajoute   |"
        echo "----------------------"
        DIFF=`diff ${TMP} ${WAY}${MVS}`
        echo "${DIFF}"

	echo ""
        echo -n "Voulez vous enregistrer ? [y,N]"
        read RESPONSE

        if [ "$RESPONSE" = "y" ]
        then
                cp ${WAY}${MVS} ${BACKMVS}${SAVE}
                cp ${TMP} ${WAY}${MVS}
                RESULT=`ls ${BACKMVS} | wc -l`

                        if [ "${RESULT}" -gt 50 ]
                        then
                                RESULT2=`ls ${BACKMVS} | head -1`
                                rm -f ${BACKMVS}${RESULT2}
			        echo ""
        			echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        			echo ""
                                echo "------------------------------------------------------------"
                                echo "| Le fichier de sauvegarde ${RESULT2} a ete efface |" 
                                echo "------------------------------------------------------------"
                        fi

		rm -f ${TMP}
	        echo ""
        	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        	echo ""
                echo "-----------------------------------"
                echo "| le fichier a ete edite et sauve |"
                echo "-----------------------------------"
                echo -e "----------------------\n| > element supprime |\n| < element ajoute   |\n----------------------\n ${DIFF}" | mail -s "Modification du MVS.CONF" ${ADR_EMAIL}

                echo -n "Voulez vous synchroniser le fichier mvs.conf ? [y,N]"
                read RESPONSE
                if [ "$RESPONSE" = "y" ]
                then
                        /ilius/scripts/distrib sync -g self ${WAY}${MVS} /
		        echo ""
        		echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        		echo ""
                        echo "----------------------------------"
                        echo "| Le fichier a ete synchronise   |"
                        echo "----------------------------------"
                fi

        else
                rm -f ${TMP}
	        echo ""
        	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"
        	echo ""
                echo "----------------------------------"
                echo "| Le fichier n'a pas ete modifie |"
                echo "----------------------------------"
                exit
        fi
fi
