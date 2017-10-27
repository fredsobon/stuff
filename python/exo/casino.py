#!/usr/bin/env python3
# -*- coding: utf8 -*-

# import module to play with random number
import random

# vars :
# recupere la valeur du number saisi par user et converti en entier : 
number = int(input("hey let's play! gimme a number between 0 and 49 : " ))

# stock d'argent dans le ortefeuille au depard
wallet = 50

# mise : argent mise en jeu 
mise = 5


# num gagnant entre 0 et 50 : 
win = random.randint(0,49)


# tests sur num saisi :

if  type(number) != int:
    print("hey ..give us a number !")
elif number < 0 and number > 49:
    print("please check the range : 0 < number < 50 : is mandatory !")
else:
    print("ok seems to be a correct number ..let's the show beguins !!")


     
# tests sur santé financiere du joueur :

if 

