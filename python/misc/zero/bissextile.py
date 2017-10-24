#!/usr/bin/env python3 
# -*- coding: utf8 -*-


# Programme testant si une ann ée , saisie par l ' utilisateur , est bissextile ou non

annee = input ( " Saisissez une ann é e : " ) # On attend que l 'utilisateur fournisse l ' ann é e qu ' il d é sire tester

annee = int ( annee ) # Risque d ' erreur si l ' utilisateur n 'a pas saisi un nombre
if annee % 400 == 0 or ( annee % 4 == 0 and annee % 100 != 0 ) :
    print ( " L ' ann é e saisie est bissextile . " )
else :
    print ( " L ' ann é e saisie n ' est pas bissextile . " )

print(input("hey ..:"))
