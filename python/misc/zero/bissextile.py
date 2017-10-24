#!/usr/bin/env python3 
# -*- coding: utf8 -*-
import os # On importe le module os qui dispose de variables
# et de fonctions utiles pour dialoguer avec votre
# syst è me d ' exploitation

# Programme testant si une ann ée , saisie par l ' utilisateur , est bissextile ou non

annee = input ( " Saisissez une année : " ) # On attend que l 'utilisateur fournisse l ' ann é e qu ' il d é sire tester

annee = int ( annee ) # Risque d ' erreur si l ' utilisateur n 'a pas saisi un nombre
if annee % 400 == 0 or ( annee % 4 == 0 and annee % 100 != 0 ) :
    print ( " L 'année saisie est bissextile. " )
else :
    print ( " L 'année saisie n'est pas bissextile. " )

print("you are here :" , os.getcwd())
