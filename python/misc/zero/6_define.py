#!/usr/bin/env python3
#-*-coding: utf8 -*-

def fonction(nb , max = 10):
    """ fonction affichant la table de multiplication de n par multi jusqu'à la valeur max. Ici on defini la valeur par defaut de max à 10: si le user ne saisi pas de param 'max'"""
    i = 1
    while i < max:
        #print("hey let's count :  + str(i) + "*" + str(nb) = ", i * nb)
        print("hey let's count : ", i * nb)
        i +=1
    return 
        
fonction(2, 30)



help(fonction)

