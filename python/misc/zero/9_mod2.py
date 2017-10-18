#!/usr/bin/env python3
#-*- coding: utf8 -*-

import os 

year = input("gimme a year : ")
year = int(year)

if year % 400 == 0 or (year % 4 == 0 and year % 100 != 0):
    print("year is bissextile !")
else:
    print(year , "classic year")



os.system("date")
print("here's the content of tmp folder : " )
os.system("ls -lh /tmp")

 
