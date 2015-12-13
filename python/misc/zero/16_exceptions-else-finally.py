#!/usr/bin/env python3
#-*- coding: utf8 -*-


import os

# var pour le try :
#a = 6
#b = 3

# var pour exception NameError :
##a =  
#b = 2

# var pour exception TypeError :
#a = 4
#b = "t"

# var pour exception ZeroDivisionError :
#a = 5
#b = 0

# ici on ne fait que l'opération dans le try :
try:
    result = a / b

# on defini maintenant quelques exceptions en fonctions des valeurs saisies et du resultat 

# ici souci : a ou b ne sont pas définis : NameError
except NameError as pb_def :
    print("nop there's a pb . did you give a number for the the two letter ?", pb_def)

# ici : une des deux variables contient autre chose qu'un nombre
except TypeError as pb_type:
    print("do you remember that a number should only contain numbers ?", pb_type)

# ici on essaye de diviser par zero : l'exception dediée est levée.
except ZeroDivisionError as pb_zero:
    print("no way ..0 can be record for divisor", pb_zero)    
# on pose un else qui va affcicher le resultat de l'opération  on dissocie cette instruction du try : c'est plus "propre" 
else:
    print("good game ! here's the result :", result)

# ici on execute une commande quel que soit le resultat du try et des excepts, else . Le bloc après finally sera donc toujours executé même si des erreurs ou des codes retour de fonctions apparaissent avant dans  notre  programme:

finally:
    os.system("date +%F-%H-%M")
