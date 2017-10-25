#!/usr/bin/env python3

# -*- coding: utf8 -*-

""" module multipli : affiche une table de multiplication."""

def multi(nb, max = 10):
    """ fonction de table de multiplication. Un nb en param :celui qui sera l'élément à multiplier . Un second param optionnel qui sera le multiplicateur : s'il est omis par défaut 10 sera utilisé. """
    i = 0
    while i < max:
        print( nb , "x", i, "=" , nb  * i )
        i += 1



