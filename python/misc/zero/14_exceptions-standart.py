#!/usr/bin/env python3
#-*- coding: utf8 -*-

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


try:
    result = a / b
    print("good game ! here's the result :", result)

# on defini maintenant quelques exceptions en fonctions des valeurs saisies et du resultat 

# ici souci : a ou b ne sont pas définis : NameError
except NameError:
    print("nop there's a pb . did you give a number for the the two letter ?")

# ici : une des deux variables contient autre chose qu'un nombre
except TypeError:
    print("do you remember that a number should only contain numbers ?")

# ici on essaye de diviser par zero : l'exception dediée est levée.
except ZeroDivisionError:
    print("no way ..0 can be record for divisor")    
