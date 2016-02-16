#! /bin/sh

if [ $# -ne 1 ]
then
	echo "usage: $0 fichier.sql" >&2
	exit 1
fi

# (Re)creer la table 
sqlite3 "$1" <<- EOF
	CREATE TABLE IF NOT EXISTS depts (
		numero	   INT,
		nom	   STRING,
		prefecture STRING,
		distance   INT
	);
EOF

ajouter_dept()
{
	sqlite3 "$1" <<-EOF
		DELETE FROM depts WHERE numero="$2";
		INSERT INTO depts VALUES("$2", "$3", "$4", "$5");
	EOF
}

	ajouter_dept "$1" "01" "Ain"               "Bourg-en-Bresse"  429
	ajouter_dept "$1" "02" "Aisne"             "Laon"             138  
	ajouter_dept "$1" "03" "Allier"            "Moulins"          300
	ajouter_dept "$1" "04" "Alpes-de-Haute-Provence"  "Digne-les-Bains" 749
	ajouter_dept "$1" "05" "Hautes-Alpes"      "Gap"              671
	ajouter_dept "$1" "06" "Alpes-Maritimes"   "Nice"             931
	ajouter_dept "$1" "07" "Ardèche"           "Privas"           603
	ajouter_dept "$1" "08" "Ardennes"          "Charleville-Mézières" 233
	ajouter_dept "$1" "09" "Ariège"            "Foix"             763
	ajouter_dept "$1" "10" "Aube"              "Troyes"           182
	ajouter_dept "$1" "11" "Aude"              "Carcassonne"      770
	ajouter_dept "$1" "12" "Aveyron"           "Rodez"            627
	ajouter_dept "$1" "13" "Bouches-du-Rhône"  "Marseille"        777
	ajouter_dept "$1" "14" "Calvados"          "Caen"             234
	ajouter_dept "$1" "15" "Cantal"            "Aurillac"         558
	ajouter_dept "$1" "16" "Charente"          "Angoulême"        452
	ajouter_dept "$1" "17" "Charente-Maritime" "La Rochelle"      471
	ajouter_dept "$1" "18" "Cher"              "Bourges"          247
	ajouter_dept "$1" "19" "Corrèze"           "Tulle"            477
	ajouter_dept "$1" "2A" "Corse-du-Sud"      "Ajaccio"          -1
	ajouter_dept "$1" "2B" "Haute-Corse"       "Bastia"           -1
	ajouter_dept "$1" "21" "Côtes-d\'Or"        "Dijon"            316
	ajouter_dept "$1" "22" "Côtes-d\'Armor"     "Saint-Brieuc"     449
	ajouter_dept "$1" "23" "Creuse"            "Guéret"           391
	ajouter_dept "$1" "24" "Dordogne"          "Périgueux"        487
	ajouter_dept "$1" "25" "Doubs"             "Besançon"         414
	ajouter_dept "$1" "26" "Drôme"             "Valence"          563
	ajouter_dept "$1" "27" "Eure"              "Évreux"           96
	ajouter_dept "$1" "28" "Eure-et-Loir"      "Chartres"         90
	ajouter_dept "$1" "29" "Finistère"         "Quimper"          564
	ajouter_dept "$1" "30" "Gard"              "Nîmes"            713
	ajouter_dept "$1" "31" "Haute-Garrone"     "Toulouse"         679
	ajouter_dept "$1" "32" "Gers"              "Auch"             715
	ajouter_dept "$1" "33" "Gironde"           "Bordeaux"         584
	ajouter_dept "$1" "34" "Hérault"           "Montpellier"      765
	ajouter_dept "$1" "35" "Ille-et-Vilaine"   "Rennes"           348
	ajouter_dept "$1" "36" "Indre"             "Châteauroux"      270
	ajouter_dept "$1" "37" "Indre-et-Loire"    "Tours"            239
	ajouter_dept "$1" "38" "Isère"             "Grenoble"         572
	ajouter_dept "$1" "39" "Jura"              "Lons-le-Saunier"  416
	ajouter_dept "$1" "40" "Landes"            "Mont-de-Marsan"   712
	ajouter_dept "$1" "41" "Loir-et-Cher"      "Blois"            185
	ajouter_dept "$1" "42" "Loire"             "Saint-Étienne"    533
	ajouter_dept "$1" "43" "Haute-Loire"       "Le Puy-en-Velay"  542
	ajouter_dept "$1" "44" "Loire-Atlantique"  "Nantes"           385
	ajouter_dept "$1" "45" "Loiret"            "Orléans"          133
	ajouter_dept "$1" "46" "Lot"               "Cahors"           575
	ajouter_dept "$1" "47" "Lot-et-Garonne"    "Agen"             710
	ajouter_dept "$1" "48" "Lozère"            "Mende"            592
	ajouter_dept "$1" "49" "Maine-et-Loire"    "Angers"           296
	ajouter_dept "$1" "50" "Manche"            "Saint-Lô"         306
	ajouter_dept "$1" "51" "Marne"             "Châlons-en-Champagne" 187  
	ajouter_dept "$1" "52" "Haute-Marne"       "Chaumont"         272
	ajouter_dept "$1" "53" "Mayenne"           "Laval"            281
	ajouter_dept "$1" "54" "Meurthe-et-Moselle" "Nancy"           384
	ajouter_dept "$1" "55" "Meuse"             "Bar-le-Duc"       251
	ajouter_dept "$1" "56" "Morbihan"          "Vannes"           463
	ajouter_dept "$1" "57" "Moselle"           "Metz"             331
	ajouter_dept "$1" "58" "Nièvre"            "Nevers"           245
	ajouter_dept "$1" "59" "Nord"              "Lille"            221
	ajouter_dept "$1" "60" "Oise"              "Beauvais"         83
	ajouter_dept "$1" "61" "Orne"              "Alençon"          249
	ajouter_dept "$1" "62" "Pas-de-Calais"     "Arras"            181
	ajouter_dept "$1" "63" "Puy-de-Dôme"       "Clermond-Ferrand" 424
	ajouter_dept "$1" "64" "Pyrénées-Atlantiques" "Pau"           794
	ajouter_dept "$1" "65" "Hautes-Pyrénées"   "Tarbes"           828
	ajouter_dept "$1" "66" "Pyrénées-Orientales" "Perpignan"      881
	ajouter_dept "$1" "67" "Bas-Rhin"          "Strasbourg"       488
	ajouter_dept "$1" "68" "Haut-Rhin"         "Colmar"           571
	ajouter_dept "$1" "69" "Rhône"             "Lyon"             465
	ajouter_dept "$1" "70" "Haute-Saône"       "Vesoul"           371
	ajouter_dept "$1" "71" "Saône-et-Loire"    "Mâcon"            402
	ajouter_dept "$1" "72" "Sarthe"            "Le Mans"          208
	ajouter_dept "$1" "73" "Savoie"            "Chambéry"         569
	ajouter_dept "$1" "74" "Haute-Savoie"      "Annecy"           543
	ajouter_dept "$1" "75" "Paris"             "Paris"            0
	ajouter_dept "$1" "76" "Seine-Maritime"    "Rouen"            132
	ajouter_dept "$1" "77" "Seine-et-Marne"    "Melun"            58
	ajouter_dept "$1" "78" "Yvelines"          "Versailles"       23
	ajouter_dept "$1" "79" "Deux-Sèvres"       "Niort"            410
	ajouter_dept "$1" "80" "Somme"             "Amiens"           139
	ajouter_dept "$1" "81" "Tarn"              "Albi"             699
	ajouter_dept "$1" "82" "Tarn-et-Garonne"   "Montauban"        630
	ajouter_dept "$1" "83" "Var"               "Toulon"           839
	ajouter_dept "$1" "84" "Vaucluse"          "Avignon"          689
	ajouter_dept "$1" "85" "Vendée"            "La Roche-sur-Yon" 425
	ajouter_dept "$1" "86" "Vienne"            "Poitiers"         347
	ajouter_dept "$1" "87" "Haute-Vienne"      "Limoges"          392
	ajouter_dept "$1" "88" "Vosges"            "Épinal"           395
	ajouter_dept "$1" "89" "Yonne"             "Auxerre"          169
	ajouter_dept "$1" "90" "Territoire-de-Belfort" "Belfort"      500
	ajouter_dept "$1" "91" "Essonne"           "Évry"             40
	ajouter_dept "$1" "92" "Hauts-de-Seine"    "Nanterre"         12
	ajouter_dept "$1" "93" "Seine-Saint-Denis" "Bobigny"          11
	ajouter_dept "$1" "94" "Val-de-Marne"      "Créteil"          13
	ajouter_dept "$1" "95" "Val-d\'Oise"        "Pontoise"         35
	ajouter_dept "$1" "971" "Guadeloupe"       "Basse-Terre"      -1
	ajouter_dept "$1" "972" "Martinique"       "Fort-de-France"   -1
	ajouter_dept "$1" "973" "Guyane"           "Cayenne"          -1
	ajouter_dept "$1" "974" "La Réunion"       "Saint-Denis"      -1
	ajouter_dept "$1" "976" "Mayotte"          "Mamoudzou"        -1



