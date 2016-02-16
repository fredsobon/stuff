#! /bin/sh

if [ $# -ne 1 ] || [ ! -f "$1" ]
then
	echo "usage: $0 <fichier>" >&2
	exit 1
fi

fic="$1"

awk '
	(NR == 1) {
		min=$1
		max=$1
	}

	{
		if ($1 < min)
			min=$1
		if ($1 > max)
			max=$1
		v[NR] = $1
	}

	END {
		nb_classes = sqrt(NR);
		classe=(max-min)/nb_classes

		for (i = 1; i <= NR; i ++) {
			nb[int((v[i]-min)/classe)] ++;
		}

		for (i = 0; i < nb_classes; i ++) {
			printf "%.2f %d\n",
			       min + i*classe, nb[i]
		}
	}
' < "$fic" > histogramme.txt

if which gnuplot > /dev/null
then
	gnuplot <<-EOF
		plot "histogramme.txt" with boxes title "$fic"
		pause mouse
	EOF
fi

