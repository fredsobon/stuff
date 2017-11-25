#!/usr/bin/env python3
#-*- coding: utf-8 -*-
import random , pickle 

### main functions file. each one is being tested at the end in a dedicated section.
## define player : 


# get the word list and write it to a file called data.py in the current dir  
liste = ["lapin", "coco" ]
file = "data.py"

def dump_list(liste):
    with open("data.py", "wb") as file:
        send_data = pickle.Pickler(file)
        send_data.dump(liste)
        
# retrieve the word liste from the data file and then get the secret word using random func :

def get_list(liste):
    with open("data.py", "rb") as file:
        get_data = pickle.Unpickler(file)
        get = get_data.load()
        print(">>>", get ,"<<<")
# check data file content : 
# got to define a number (equal to the lenght of list minus 1 : to be in a correct range :
word_index = random.randint(0,len(liste)) - 1
word = liste[word_index]
def test(word):
    try:
        assert 0 < len(word) < 8
        print("ok the secret word is correct and is : "  , word.upper() )
    except AssertionError: 
        print("no way the given word is over string limit !")  
        exit()
## retrieve  the letter given by the player : 
letter = input("give us a letter:" )
print("ok you choose :", letter)

def fonc(letter):
    print("let us try to find if", letter ," is in the secret word !!")
    return

## let's printout choosen letter in secret word if present :

def game():
    for x in word:
        if x == letter:
            print(letter)
        else:
            print("*")
    return word

## test func inside the module itself :
if __name__ == "__main__":
    dump_list(file)
    get_list(liste)
    test(word)       
    fonc(letter) 
    game()
