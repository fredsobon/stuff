#!/usr/bin/env python
# -*- coding: utf8 -*-
name="maggie"


# on commence à compter à partir de 0 : omer=0 marge=3 . On peut creeer une liste vide []. On peut melanger les types.
lst=["omer", "bart" , "lisa" , "marge"]

print(lst[2])

# va afficher lisa
# pour un intervalle on inclu la première borne et on exclu la dernière : lst[1:3]

print(lst[1:3])

# va afficher ['bart', 'lisa']

#print(lst[:2])  : on affiche tout jusqu'à 2 exclu
#print(lst[:]) : on affiche tous les elements. onpeut definir une nouvelle liste qui sera une copie de notre liste:
liste2=lst[:]

#python considere le texte comme une liste de lettres :
print("texte"[1:3]) 

# on va voir qu'on peut modifier une liste. Ici on copie notre liste . On affecte la valeur de la variable name à l'element 2 de notre liste : 
simpson=lst

lst[2]=name

print(lst)

# on a donc dans la liste lst et simpson les valeurs :["omer", "bart" , "maggie" , "marge"] .Simpson est un alias de lst

# Si on affiche liste2 : elle n'aura pas changée : ["omer", "bart" , "lisa" , "marge"] . 

# il faut faire attention au copies.

# boucle for

for elem in lst:
    print("hello , in the loop")
    print elem

#hello , in the loop
#omer
#hello , in the loop
#bart
#hello , in the loop
#maggie
#hello , in the loop
#marge

