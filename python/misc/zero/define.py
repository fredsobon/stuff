#!/usr/bin/env python3
#-*-coding: utf8 -*-

def fonction(nb , max = 10):
    """ fonction affichant la table de multiplication de n par multi jusqu'à la valeur max de 10."""
    i = 1
    while i < max:
        #print("hey let's count :  + str(i) + "*" + str(nb) = ", i * nb)
        print("hey let's count : ", i * nb)
        i +=1
    return 
        
fonction(42)



help(fonction)

