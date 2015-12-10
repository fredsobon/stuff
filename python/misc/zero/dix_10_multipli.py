#!/usr/bin/env python3
#-*- coding: utf8 -*-

"""module multipli contenant la fonction table"""

def table (nb, max =10):
    """Fonction affichant la table de multiplication par nb de 1 * nb jusqu'à max nb """
    i = 0
    while i < max:
        print(i + 1, "*" ,nb, "=", (i + 1) * nb)
        i +=1

if __name__ == "__main__":
    table(5)
    os.system("date +%F")



