#!/usr/bin/env python3
#-*- coding: utf8 -*-

year = input("gimme a year upper than 0 :")

try:
    year = int(year)
    assert year > 0
except ValueError as number_plz:
    print("hey wake up !" , number_plz)
except AssertionError:
    print("did you read ?")
