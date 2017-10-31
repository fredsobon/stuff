#!/usr/bin/env python3
# -*- coding: utf8 -*-

# import module to play with random number
import random

# vars :
# recupere la valeur du number saisi par user et converti en entier : 
number = int(input("hey let's play! gimme a number between 0 and 49 : " ))

# stock d'argent dans le ortefeuille au depart
wallet = 50

# mise : argent mise en jeu 
mise = 5

# num gagnant entre 0 et 50 : 
win = random.randint(0,49)

# color 
if win % 2 == 0:
    color = "red"
else:
    color = "black"

# tests sur num saisi :
if  type(number) != int:
    print("hey ..give us a number !")
elif (number < 0) or (number > 49):
    print("please check the range : 0 < number < 50 : is mandatory !")
    exit(1) 
else:
    print("ok seems to be a correct number ..let's the show beguins !!")

# tests sur santé financiere du joueur :
if wallet <=  0:
    print("No way bankroute man !")
elif wallet  <= mise:
    print("no way : not enough money!! got to bet lower as mise")
else:
    print("ok let's gambling !")


# first step verif des différents param :
print("the player chose", number)
print("the winning number is", win)
print("we got a :" , color)
print("financials infos : wallet content: ", wallet , "and the mise is about :", mise)

# tests on number played : value, color ...win or loose ...

if number == win:
    print(" We got a winner !! well done amigo ..") 
    wallet = wallet + ( mise * 3)
    print(" all right ..right now you got :", wallet , "in yo pocket!")
elif ( number % 2 == 0 and color == "red" ) or (  number % 2 != 0 and color == "black"):
    print("the winning number you got the right color guy ! you got it ")
    wallet = wallet + ( mise / 2)
    print(" all right ..right now you got :", wallet , "in yo pocket!")
else:
    print("you loose man ....")
    wallet  = wallet - mise
    print(" all right ..right now you got :", wallet , "in yo pocket!")

