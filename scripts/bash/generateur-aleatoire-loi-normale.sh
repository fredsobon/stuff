#! /bin/bash

if [ $# -ne 4 ]
then
	echo usage: $0 nb_valeurs mini maxi ecart_type
	exit 1
fi

nb_valeurs="$1"
mini="$2"
maxi="$3"
ecart_type="$4"

i=0
while [ $i -lt $nb_valeurs ]
do
	# Deux valeurs aleatoires entre 1 et 10000
	RAND1=$(( 1 + ${RANDOM} % 10000))
	RAND2=$(( 1 + ${RANDOM} % 10000))

	# Methode de Box-Müller
	bc -l <<-EOF
		moyenne=(${maxi}+${mini})/2
		pi=4*a(1)
		moyenne + ${ecart_type} * \
                          sqrt(-2 * l(${RAND1}/10000)) * \
                          c(2 * pi * ${RAND2}/10000)
	EOF

	i=$(( i+1 ))
done


