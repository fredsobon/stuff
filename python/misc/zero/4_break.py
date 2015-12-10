#!/usr/bin/env python3
#-*-coding: utf8 -*-

while True:
    a = input("gimme the secret to quit :" )
    print("you gave me " + a)
    if a  in "qQ":
        print("ok bye")
        break
    else:
        print("try again")

