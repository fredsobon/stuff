#!/usr/bin/env python3
#-*- coding: utf8 -*-


import os

"""module multipli contenant la fonction table"""

def table (nb, max =10):
    """Fonction affichant la table de multiplication par nb de 1 * nb jusqu'à max nb """
    i = 0
    while i < max:
        print(i + 1, "*" ,nb, "=", (i + 1) * nb)
        i +=1
# on a un moyen de pouvoir tester la validité de notre fonction en utilisant la méthode suivante : tester la fonction en lancant le script lui-même permet de setter  les variables python  '__name__' et '__main__' et donc invoquer notre fonction directement au sein du script . Si l'appel est externe alors le test __name__ == "__main__" n'est pas vrai donc pas de suite. Cette méthode est TRES utilisée.

if __name__ == "__main__":
    table(5)
    os.system("date +%F")



