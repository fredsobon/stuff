#!/usr/bin/env python3
#-*-coding: utf8 -*-

i = 1
while i < 10:
    if i % 2 == 0:
        print("hey even number ... " + str(i))
        i += 1
        continue
    print("odd one : " + str(i))
    i += 3

