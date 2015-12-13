#!/usr/bin/env python3
# -*- coding: utf8 -*-

import os

annee = input("hey gimme me a number plz :")

# on essaye de convertir en entier la chaine retournée par le user 
try:
    annee = int(annee) 
# si la conversion n'est pas possible ( aka si le code retour de l'instruction n'est pas ok alors on agit differement  
except:
    print("hey no way ! a number do you understand ?")

