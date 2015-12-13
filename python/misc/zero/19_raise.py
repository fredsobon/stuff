#!/usr/bin/env python3
#-*- coding: utf8 -*-

year = input("gimme a year upper than 0 :")

try:
    year = int(year)
    if year <= 0:
        raise ValueError("yop ..upper than 0 plz !")
except TypeError:
    print("no way ! ")
