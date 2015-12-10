#!/usr/bin/env python3
#-*-coding: utf8 -*-

word = "lapin"

for w in word:
    if w in "aeiouy":
        print("hey yougot voyel :" + w)
    else:
        print("secret char: ###")

