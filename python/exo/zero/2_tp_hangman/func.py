#!/usr/bin/env python3
#-*- coding: utf-8 -*-
import random


## define player : 


## define secret word :

liste = ["lapin", "coco" ]
# got to define a number (equal to the lenght of list minus 1 : to be in a correct range :
word_index = random.randint(0,len(liste)) - 1
word = liste[word_index]
def test(word):
    if len(word) > 8:
        print("no way the selected word is too long  !")
    else:
        print("ok the secret word is correct and is : "  , word.upper() )
test(word)       


## retrieve  the letter given by the player : 
letter = input("give us a letter:" )
print("ok you choose :", letter)

def fonc(letter):
    print("let us try to find if", letter ," is in the secret word !!")
    return

fonc(letter) 

## let's printout choosen letter in secret word if present :

def game():
    for x in word:
        if x == letter:
            print(letter)
        else:
            print("*")
    return word
game()




