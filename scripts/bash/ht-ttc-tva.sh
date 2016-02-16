#! /bin/sh

printf "Montant HT ? (Entree pour passer) "
if ! read ht ; then exit 0; fi
if [ "$ht" != "" ]
then
	echo "$ht" | \
	awk '{ ht=$1; ttc=ht*1.196; tva=ht*.196 }
		END { printf "HT=%.2f TTC=%.2f (TVA=%.2f)\n",
	                      ht, ttc,tva }'
	exit 0
fi

printf "Montant TTC ? (Entree pour passer) "
if ! read ttc ; then exit 0; fi
if [ "$ttc" != "" ]
then
	echo "$ttc" | \
	awk '{ ttc=$1; ht= ttc/1.196; tva=ht*.196 }
	     END { printf "HT=%.2f TTC=%.2f (TVA=%.2f)\n",
	                   ht, ttc,tva }'
	exit 0
fi

printf "Montant TVA ? (Entree pour passer) "
if ! read tva ; then exit 0; fi
if [ "$tva" != "" ]
then
	echo "$tva" | \
	awk '{ tva=$1; ht=tva/0.196; ttc=ht*1.196 }
	     END { printf "HT=%.2f TTC=%.2f (TVA=%.2f)\n",
                           ht, ttc,tva }'
	exit 0
fi

