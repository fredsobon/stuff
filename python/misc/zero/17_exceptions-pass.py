#!/usr/bin/env python3
#-*- coding: utf8 -*-


import os

# var pour le try :
#a = 6
#b = 3

# var pour exception NameError :
##a =  
#b = 2

# ici on ne fait que l'opération dans le try :
try:
    result = a / b


# ici on rajoute "pass" : on peut l'utiliser quand on veut tester un bloc mais ne rien faire si on rencontre une erreur. On ne peut pas le faire avec un try seul ..il faut donc rajouter pass qui ne fait rien même en cas d'exception rencontrées ( pas vraiment d'interet mais il est bon de savoir que ce mot clé existe. on peut l'avoir dans des fonctions qu'on veut vides , conditions etc ...

except: 
    pass 

