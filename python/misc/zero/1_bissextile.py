#!/usr/bin/env python3
#-*-coding: utf8 -*-
import os 


b = input("gimme a year : ")

print("ok you gave me " + str(b))
year = int(b)


if year % 4 == 0 or year % 400 == 0:
    print("you got it!")
else:
    year % 100 == 0
    print("nop")


