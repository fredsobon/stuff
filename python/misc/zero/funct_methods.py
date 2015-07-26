#!/usr/bin/env python
# -*- coding: utf8 -*-

# int() ; raw_input() ; str() ... : une fonction retourne une donnée. var=fonction(truc)  print var. 
# le retour de la fonction est different en fonction de ce sur quoi elle s'applique.Exemple diférence entre le len("mot") len("lapin"," "lulu") : on a d'un coté le nombre de lettre du mot et dans l'autre exemple le nombre d'élement de la liste .

print(len("monty"))
print(len(["lapin", "lulu"]))


print(range(5))
compte=3

for x in range(compte):
    print("hip")


#[0, 1, 2, 3, 4]
#hip
#hip
#hip
#

# Une methode est attachée au type . Pour appeller une fonction , on tape son nom et entre parenthese ses params: fonction(param) Pour invoquer /appeller une methode , on saisi le nom_var.nom_methode(param) . 
# On voit ici clairement les methodes associées au type str . La methode upper met tout en maj , la methode capitalize met 'initale en maj , la methode title met toutes les premieres lettres en maj ( utiles pour nom composés) :
nom="napoleon"
print(nom.upper())
print(nom.capitalize())

name="Louis-philipPE"
print(name.title())

# on peut nettoyer le code ; les entrees des users : exemple supprimer des espaces en trop avec strip :

a="          ..blabla avec plein d'espaces au debut et à la fin....       "
print(a)

print(a.strip())

#nous affiche dans un premier temps          ..blabla avec plein d'espaces au debut et à la fin....       puis clean des espaces :
#..blabla avec plein d'espaces au debut et à la fin....


#On peut transformer du texte en liste en utilisant un separateur :
b="lapin,lulu,lili"
print(b)
print(b.split(","))

# nous affiche bien les mots , puis une liste dont le sep est la ","
#lapin,lulu,lili
#['lapin', 'lulu', 'lili']


