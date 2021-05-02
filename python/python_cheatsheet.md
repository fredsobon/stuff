# python - cheat sheet 

### types
- string :
chaine de caractères
on essaye d'écrire entre double quote. En simple quote on doit protéger les caractères spéciaux :
```
>>> print("hello world!")
hello world!
>>> print("jack's on the way!")
jack's on the way!
>>> print('jack\'s on the way!')
jack's on the way!
```

on peut faire du multiligne avec trois quillemets simples :
```
>>> print('''jack 's on the way!\n back to \n New Orleans !''')
jack 's on the way!
 back to 
 New Orleans !
``` 

Attention aux caractères speciaux interprétés par python : 
```
\a caractere d'appels 
\b caractere retour arriere
\f caractere de saut de page
\n retour à la ligne
\r retour chariot 
\t tabulation horizontale
\v tabulation verticale`
```
si on veut utiliser ces caractères dans un texte il faudra proteger ce texte en ajoutant la valeur "raw string" avant notre texte :
```
>>> print(r"\t ..got a tab!")
\t ..got a tab!`
```
- numeriques :
2 types entiers(positif ou negatif) et decimal float (nbre à virgule) : les decimaux s'écrivent avec un point ( pas de virgule sinon erreur ) 
17 -5 12.54 1.0 
depuis python3.6 on peut mettre le separateur "_" pour rendre les nombre plus lisible :
```
>>> print(10_000)
10000
```
- boolean :
True False
True vaut 1 et False vaut 0 
les booleans sont une sous classe de la classe entier int 
```
>>> issubclass(bool,int)
True`
`>>> print(True + 4)
5
>>> print(False - 1)
-1
```
Tous les objects ont une valeur True ou false :
```
bool("hello)
True`
```
seule une chaine de caractere vide sera considérée comme False.Pour les int et float seules les valeurs à 0 ( pour un entier ) et 0.00 pour un decimal sont False.
Les listes et dico vides sont considérés comme False.

Tous les types de base peuvent être construits avec leur classe correspondante :
str(), int(), float(), bool()
Python détecte le type grâce par exemple aux guillemets pour les strings , au point pour les float ..
On va pouvoir utiliser ces classes pour convertir des types.ex :
```
>>> a=str(5.5)
>>> type(a)
<class 'str'>
>>> a=bool("True")
>>> type(a)
<class 'bool'>
```
attention on peut avoir des erreurs : on ne peut pas biensur convertir un mot en nombre ..

### variables

- intro
python va gérer la mémoire pour nous.
une var est un nom associé à un object 
a = 5 . 
Le nombre 5 est stocké dans la variable
si on cree b = 5 . on ne crée pas de nouvel object a et b pointe vers l'object 5.
si on redefini a et b ex : a = 7 , b = 8 alors python va detruire l'object 5 vers qui plus personne ne pointe avec le garbage collector.
on peut verifier la place occupée en mémoire par un object avec la commande id :
```
>>> a = 7
>>> id(a)
9476608
>>> a = "lapin"
>>> id(a)
140500855859440`
>>> b = a
>>> id(b)
140500855859440 #  on voit ici que a et b pointent sur le même object en mémoire.
```
- affectations :
```
-> simple 
>>> a = 7
-> parallele :
>>> a,b=7,10
>>> print(a,b)
7 10
>>> a,b=b,a
>>> print(a,b)
10 7
-> affectation multiple :
>>> a = b = c = 5 
>>> print(a,b,c)
5 5 5
```
- singleton  small integer caching :

singleton sera un mot unique :
on aura toujours la même valeur stocké en mémoire
```
>>> id(True)
9183136
>>> id(None)
9253312
>>> id(False)
9183104
```
ce n'est pas le cas avec les objects par exemple num dans des anciennes versions de python ou on retrouve les même id mémoires pour les singletons, les nombre entre -5 et 256 et les chaines inferrieures à 20 caracteres : ce qu'on appelle les small integer caching.

- regles de nommages :
à respecter :
une var ne peut pas commencer par un chiffre 
peut pas contenir d'espace ni de tiret 
certains mots sont reservés (True,False,break,None ..)
attention à la casse ( nom != Nom )

convention python :
tout en minuscule . mots séparés par un "_" 

## convertion de type d'objet 

-> python est dynamique : pas besoin de preciser le type de notre variable
```
p = 5
p = "python"
```
les languages statiques eux imposent de préciser le type. ex : c++ :

`int ma_var = 5;`

-> python est fortement typé :
on ne peut pas ajouter des objets de type différents :
```
>>> 50 + "50"
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: unsupported operand type(s) for +: 'int' and 'str'
```
javascript lui permet le permet :
50 + "50" nous donne "5050" 

Il va falloir gérer le type des entrées fournies par le user : il faudra donc controller le type des variables et pouvoir les convertir si besoin.
ex : changer une chaine de caractere en entier et inversement 

```
>>> a = 5
>>> b = "10"
>>> type(a)
<class 'int'>
>>> type(b)
<class 'str'>
>>> a + b
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: unsupported operand type(s) for +: 'int' and 'str'
>>> a + int(b)
15
```
Pour nous assurer du traitement correct de nos variables on va donc devoir convertir. Car sinon le traitement de variable fera des erreurs :
```
>>> b = "4"
>>> int(b)
4
>>> type(b) # ici on voit que la valeur de b n'est pas changé et qu'on est toujours en string 
<class 'str'>
```
```
>>> a = 7
>>> b = "7"
>>> b = int(b)
>>> type(b)
<class 'int'>
>>> c = a * b
>>> print(c)
49
```

Bien s'assurer de la valeur de nos variable avec la fonction type.
on peut utiliser la fonction isdigit pour assurer que la variable ne contient que des nombre 
```
>>> "lapin".isdigit()
False
>>> "2022".isdigit()
True
```

### interraction utilisateur :

on va utiliser la fonction input pour nous permettre de recevoir les données saisies par un utilisateur.
```
>>> nbr= input("gimme a number: ")
gimme a number: 10
>>> print(nbr)
10
```

```
>>> pr = input("gimme yo name : ")
gimme yo name : bob
>>> age = input("how old are you ? ")
how old are you ? 15
>>> city = input(" where y come from ? ")
 where y come from ? chicago
>>> print("hello" + pr + "you are " + age + "old" + "and you come from " + city + "city")
hellobobyou are 15oldand you come from chicagocity
>>> print("hello" + " "+ pr + " !" +  "You are " + " " + age + " " + "old" + " " + "and you come from " + " " + city + " " + "city")
hello bob !You are  15 old and you come from  chicago city
```
### Manipulation de chaine de caractères :

on va utiliser des méthodes (méthodes spéciales qui vont agir sur des objets.)

- Methodes sur chaines de caracteres :

- changement de casse :

- upper : met les caracteres en maj :
>>> "lapin".upper()
'LAPIN'
>>>

- lower : met les caracteres en minuscule :
>>> "ZOUZOU".lower()
'zouzou'
>>>

- Capitalize : met une maj au debut d'une chaine de caractère :
>>> "hello, les mecs !".capitalize()
'Hello, les mecs !'
>>>

- Title : permet de mettre une maj à tous les mots d'une chaine :
>>> "hello, les mecs !".title()
'Hello, Les Mecs !'
>>>


- remplacement de caractères :

- replace :
on va  pouvoir remplacer une chaine de caractère sélectionner par une autre avec la methode replace.
"car".replace("chaine_à_remplacer", "chaine_qui_va_remplacer")

>>> "bonjour".replace("jour", "soir")
'bonsoir'
>>>
cette methode remplace toutes les occurences dans le texte :
>>> "bonjour, bonjour".replace("jour", "soir")
'bonsoir, bonsoir'
>>>
fonctionne aussi pour les caractères autre que lettres : ex :caractere vide :
>>> "bonjour, bonjour".replace(" ", "")
'bonjour,bonjour'
>>>
on peut chainer les remplacements :
>>> "bonjour, bonjour".replace(" ", "").replace("jour", "soir")
'bonsoir,bonsoir'
>>> 

- strip :
methode un peu particulière 
De base strip sans argument strip supprime les espaces.
Cette commande supprime au debut et à la fin 

>>> "  bonjour   ".strip()
'bonjour'
>>>
pour la suppression de caractere se fait unitairement : une suite de caractere qu'on veut delete. Ex ici on va del un espace u j o et r 
>>> "  bonjour   ".strip(" ujor")
'bon'
>>>

On peut spécfier un coté que l'on veut traiter ex : si on veut delete la fin :

>>> "  bonjour   ".rstrip(" ujor")
'  bon'
>>>

si on delete le debut :
>>> "  bonjour   ".lstrip(" ujor")
'bonjour   '
>>>

Attention cette methode comme replace va agir sur toutes les chaines de caractères du texte.


- Separer et joindre :

- split :
il peut nous arriver de devoir séparer les caracteres :
ici on separe la chaine de caractere par "," + espace : ce qui nous donne une liste de caractere :
>>> "1, 2, 3, 4".split(", ")
['1', '2', '3', '4']
>>>

- join :
join va nous permettre de faire l'inverse et de pouvoir transformer par exemple une liste en chaine de caractère séparée par un délimiteur que l'on defini.
ex : ici on va separer les éléments d'une liste par une virgulle et un espace :
>>> ", ".join(['1', '2', '3', '4'])
'1, 2, 3, 4'
>>>

on peut cumuluer les méthodes ..on revient donc à la case départ :
>>> ", ".join("1, 2, 3, 4".split(", "))
'1, 2, 3, 4'
>>> 

Attention ceci ne fonctionne que sur les chaines de caractères.

- zfill :
remplir de 0 des chaines de caractères 
ex pour avoir des sequences de nombre identiques :
>>> "9".zfill(2)
'09'
>>> "9".zfill(4)
'0009'
>>> 
>>> for i in range(10):
...     print(str(i).zfill(2))
... 
00
01
02
03
04
05
06
07
08
09


- verification des types de caractères :

les methodes commencent par is :

>>> "bob".islower()
True
>>> "bob".isupper()
False
>>> "Bob".islower()
False
>>> "Bob".istitle()
True
on peut verifier qu'une chaine ne contient que des nombres : 
>>> "50".isdigit()
True
>>> "50 yes".isdigit()
False
>>>

- compter les occurences :

la methode count va compter le nombre d'occurence de caractère qui nous interresse :
>>> "bonjour, le jour".count("jour")
2
>>>
en rajouter un espace devant notre chaine de caractère on a un resulat différent :
>>> "bonjour, le jour".count(" jour")
1

- find :
on va ici trouver l'emplacement de notre chaine de caractère :
>>> "bonjour, le jour".find("jour")
3

en python on commence a compter à 0 : on voit ici que notre chaine "jour" commence au 4 eme caractere : soit le numero 3 en python 

>>> "bonjour, le jour".find("le")
9

on peut utiliser la méthode index aussi :

>>> "bonjour, le jour".index("jour")
3

Si la chaine de caractere n'est pas présente python renvoit 
avec find un négatif :
>>> "bonjour, le jour".find("bla")
-1
avec index une erreur :
>>> "bonjour, le jour".index("bla")
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
ValueError: substring not found
>>>

on a la sous methode r pour find comme avec strip :

>>> "bonjour, le jour".rfind("jour")
12

- verifier qu'une chaine commence ou fini par un caractere :
methodes endswith et startwith 
ex : on cherche les fichiers par extension 

>>> "lapin.jpeg".endswith("jpeg")
True
>>> "lapin.jpeg".endswith("png")
False

>>> "lapin.jpeg".startswith("lapin")
True
>>> "lapin.jpeg".startswith("carotte")
False

exo : sortir les mots suivants triés par ordre alphabetique : 

>>> chaine = "Pierre, Julien, Anne, Marie, Lucien"

# on sépare les caracteres par ", " 
>>> liste = chaine.split(", ")
# on a une liste qu'on va trier par ordre alphabetique : 
>>> liste.sort()
# cette liste triée va être traiteé et on va ajouter ", " puis la transformer en chaine de caractère :
>>> chaine_en_ordre = ", ".join(liste)
>>> print(chaine_en_ordre)
Anne, Julien, Lucien, Marie, Pierre

### les operateurs :

# differents operateurs 

+ - * / : habituels.

>>> print(5 + 3)
8
>>> print( 12 - 7)
5
>>> print( 2 * 7)
14
>>> print(14 / 7)
2.0   <<<< attention la / nous retourne un nombre décimal.

on peut aussi utiliser ces operateurs mathematiques avec des chaines de caractères :
ex concaténation

>>> print("Hello" + "world" + "!")
Helloworld!
>>> print("bob" * 2)
bobbob

Il y a d'autres opérateur  
% // et ** 

- modulo % : reste de la division :

>>> print( 10 % 3)
1
>>> print( 10 % 5)
0

- division entiere  // : permet de récupérer en nombre entier dans une division :

>>> print( 10 / 3)
3.3333333333333335
>>> print( 10 // 3)
3

- puissance ** : permet le passage au carré :

>>> print(2 ** 4)
16

pour des besoins de calculs plus complexes on va pouvoir utiliser le module math de python qui va intégrer beaucoup de notions mathématiques (cosinus, radian ....)

on importe le module :

import math

puis on utilise les fonctions mathématiques voulues en préfixant du module math :
ex :

>>> import math
>>> racine = math.sqrt(4)
>>> print(racine)
2.0
>>> racine = math.sqrt(2)
>>> print(racine)
1.4142135623730951

>>> print(math.pi)
3.141592653589793

# operateurs d'assignation :

on connait :
i = 1
on peut faire :

i = i +1

on peut faire plus simple :
>>> i = 1
>>> i += 1
>>> print(i)
2
>>> i += 1
>>> print(i)
3

c'est valable pour tous les opérateurs mathématiques :

>>> i = 3
>>> i -= 1
>>> print(i)
2
>>> i *= 2
>>> print(i)
4
>>> i /= 2
>>> print(i)
2.0

# operateurs de comparaison :

> : sup à
< : inf à
>= : sup ou egal à
<= : inf ou egal à
== : egal 
!= : diff

différence entre is et == 

is permet de vérifier les adresses des objects en mémoire
== permet de verifier l'egalité de 2 objects.

>>> a = [1,2,3]
>>> b = [1,2,3]
>>> a == b
True
en examinant les objects en mémoire on a : 
>>> id(a)
139692687725568
>>> id(b)
139692686968128
et donc :
>>> a is b 
False


attention pour les nombres entier -5 et 256 : pour optimiser les process python place ces ranges dans les même cases mémoires :

>>> a = 7
>>> b = 7
>>> a is b
True
>>> id(a)
9476608
>>> id(b)
9476608
>>> a = 256
>>> b = 256
>>> a is b
True
>>> id(a)
9484576
>>> id(a)
9484576
>>> a = 257
>>> b = 257
>>> a is b
False
>>> id(a)
139692686516112
>>> id(b)
139692686515312

### formatage des chaines de caractères :

la concatenation permet de mettre bout à bout plusieures chaines de caractères.
>>> "bonjour" + "tout" + "le" + "monde"
'bonjourtoutlemonde'

- methode : f-strings:

depuis la version 3.6 

>>> prenom = "bob"
>>> f"Hello, {prenom}"
'Hello, bob'
on peut faire des opérations sur les variables définies 
>>> a = 70
>>> b = 5
>>> f"hey , {a} multiplié par {b} nous donne {a * b}"
'hey , 70 multiplié par 5 nous donne 350'
pas besoin d'utiliser les fonctions de convertion pour l'affichage string num 

ex: 
protocole = "https://"
nom_du_site = "docstring"
extension = "fr"
page = "glossaire"

# Modifiez le code à partir d'ici
URL = f"{protocole}www.{nom_du_site}.{extension}/{page}/"

- methode format :

avant python 3.6 donc pas de f-strings : on peut utiliser la méthode format :

on va identifier une variable dans du texte via une paire d'accolade. Attention il faut autant de paire d'accolade que de variables définie.
>>> age = 77
>>> "Hey im {} years old!".format(age)
'Hey im 77 years old!'

>>> a = "bob"
>>> b=12
>>> "hey my name is {} and i'm {}".format(a,b)
"hey my name is bob and i'm 12"


on peut ajouter des noms (identifiants)  à ce qui est entre accolades :
ce qui nous permet d'identifier et placer les variables dans l'ordre voulu 
>>> age = 12
>>> "Hey im {a} years old!".format(a=age)
'Hey im 12 years old!'

>>> age = 12
>>> heure = 11
>>> "Hey im {a} years old in have to go back at {b} hours !".format(a=age, b=heure)
'Hey im 12 years old in have to go back at 11 hours !'

on peut ajouter des index de manière a utiliser plusieurs fois une chaine de caractères :

>>> b=12
>>> "hey im {0} and i need to go back at {0} oclock!".format(b)
'hey im 12 and i need to go back at 12 oclock!'

>>> b=12
>>> c="bab"
>>> "hey im {0} and i need to go back at {0} oclock! at {1} house".format(b,c)
'hey im 12 and i need to go back at 12 oclock! at bab house'

on peut spécifier l'ordre que l'on veut :
>>> p = "Peter"
>>> t = "man"
>>> print(" i m a {1}, and my name is {0}".format(p,t))
 i m a man, and my name is Peter


Dans quel cas utiliser la méthode format ?
avec la méthode f-strings on est obligé d'avoir toutes les variables définies avant de pouvoir traiter le texte sinon on a une erreur 
ex: 
>>> a = "bob"
>>> print(f"hello my name is {a} and i live in {z}")
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
NameError: name 'z' is not defined

format est donc potentiellement une méthode a savoir utiliser.

https://www.docstring.fr/blog/le-formatage-des-chaines-de-caracteres-avec-python/?utm_source=udemy&utm_campaign=formatage-chaines

exercice :
>>> n1 = int(input("Gimme a number : "))
Gimme a number : 10
>>> n2 = int(input("gimme another number : "))
gimme another number : 15
>>> print(f" the addition of {n1} and {n2} is {n1 + n2}")
 the addition of 10 and 15 is 25

on peut tout mettre dans un fichier .py et executer :
a = input("Entrez un premier nombre : ")
b = input("Entrez un deuxième nombre : ")
print(f"Le résultat de l'addition de {a} avec {b} est égal à {int(a) + int(b)}")

 ./main.py                                                                                                                                                             [☸ |N/A:default]
Entrez un premier nombre : 7
Entrez un deuxième nombre : 7
Le résultat de l'addition de 7 avec 7 est égal à 14

== structures conditionnelles ==

permet de tester une condition pour faire une action ou non.
ex: 
l'age saisi par le user est-il supérieur à 18
    age >= 18
le user est il dans la bdd
    nom_user in list_users
le mdp du user fait i l au moins 8 caracteres.
   len(mdp) > 8
on repond par oui ou non : un booleen.

Le test de condition se fera avec :
if cond alors action

>>> age=20
>>> if age >= 18:
...     print("hey allok access granted !")
...
hey allok access granted !

on remarque qu'on a un ":" a la fin de la ligne du test et que la ligne d'action est indenté de 4 caractères vers la droite par rapport à la ligne de test : c'est un bloc d'instruction.

= bloc d'instructions :
regroupe une ou plusieurs ligne de code executée dans un contexte particulier

on a une notion d'appartenance au bloc précédent.
avec python c'est la mise en page qui précise l'appartenace 
>>> age=20
>>> if age >= 18:
...     print("hey ok you can vote !")
...     if age >= 20:
...         print("hey have you ever vote ?")
...
hey ok you can vote !
hey have you ever vote ?


= elif = 

on peut utiliser plusieurs structures conditionnelles 
exemple on peut tester et faire une action différente en raison d'un valeur saisie :

>>> age=20
>>> if age >= 18:
...     print("all right you can vote!")
... elif age <=18:
...     print("got to wait to vote!")
...
all right you can vote!

= else =

permet d'executer un bloc de code si les conditions précédentes ne sont pas executées.
>>> user="bob"
>>> if user == "admin":
...     print("access granted!")
... elif user == "root":
...     print("you're the boss")
... else:
...     print("no way!")
...
no way!

= operator ternaire : =
va permettre de mettre des structures conditionnelles sur une seule ligne 

>>> age = 20
>>> maj = True if age >= 18 else False
/!\ cette structure ne fonctionne que pour un test en if else (pas de elif else) 

A utiliser pour des test simples. 

= operateur logiques : =

and or not
on va pouvoir vérifier plusieurs conditions 
- and 
>>> user = "admin"
>>> if user == "admin" and password == "admin":
...     print("acces granted")
toutes les conditions doivent être vérifiées :
>>> 5 > 2 and 5 < 10
True

>>> 5 > 2 and 5 < 10 and 5 > 15
False

toutes les conditions doivent être True

- or 
on peut avoir une ou plusieurs conditions à True . Un seul True suffit a ce que le resultat est vrai.

>>> 5 > 2 and 5 < 10 or 5 > 15
True

/!\ attention python examine les sections de code 'and' en priorité puis les sections 'or'

On peut forcer l'examun des en ajoutant des parenthèses à nos blocs de test :
dans le cas suivant le bloc (5 < 10 or 5 > 15) sera evalué en premier ( comme en mathématiques classiques.)
>>> 5 > 2 and (5 < 10 or 5 > 15)
True

- not :

not True > False
not False > True
ici si l'utilisateur n'est pas admin on ne le laisse pas accéder :
>>> user="bob"
>>> if not user == "admin":
...     print("acces denied!")
...
acces denied!

== gestion des erreurs pythons : ==

= erreur de syntaxes :

oubli de maj, de virgule ...

ex :
ici on fait une boucle en mettant une maj a "for" :

>>> For i in range(10):
  File "<stdin>", line 1
    For i in range(10):
        ^
SyntaxError: invalid syntax
        
ici on voit que l'erreur mentionne la sortie sur stdin (on a lancer la commande depuis un interpreteur python. Si on executait la commande depuis un un script on aurait le chemin complet du script en erreur 

On voit qu'on a un accent circonflexe sous le i ce qui nous montre l'endroit jusqu'auquel l'interpréteur python est allé avant de crasher.

erreurs courantes : 

-> erreur de casse : on doit assurer à donner la bonne orthographe
-> oubli des ":" dans les blocs d'instructions 
-> utilisation de mot réservés en python 
-> oubli des guillemets.

= mots réservés en python : =

False
None
True
and
as
assert
break
class
continue
def
del
elif
else
except
finally
for
from
global
if
import
in
is
lambda
non local
not
or
pass
raise
return
try
while
with
yield

= erreurs d'éxécutions :

elles se produisent pendant le runtime du programme 
RuntimeError : 
il se peut que le programme fonctionne correctement mais qu'une situation non prise en compte fasse crasher le programme.

Les erreurs de runtime peuvent être trs nombreuses et python nous aide en nous affichant le type d'erreur rencontrée 

ex : NameError 
NameError : on essaye par exemple d'afficher une variable qui n'existe pas .
>>> print(bonjour)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
NameError: name 'bonjour' is not defined

ex : TypeError on additionne des valeurs de type différent par exemple :

>>> "4" + 7
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: can only concatenate str (not "int") to str

il ya beaucoup d'autre type d'erreurs de runtime

= erreur semantique : =

erreur de logique : notre script ne retourne pas ce que l'on veut.
On peut s'aider d'un debugger avancer .
on peut  sinon ajouter une fonction print pour afficher nos variables et autres afin de nous aider à débugger.

== modules et fonctions : ==

module : fichier python qui contient des fonctions que l'on peut utiliser.
on va devoir importer ces modules pour les utiliser.

Il y a des modules inclus dans la librairie standart de python et d'autre qu'on devra downloader.
dans tous les cas il faut importer le module 

le keyword import est utilisé.

import mon_module

une fois le module importer on peut utiliser ses fonctions 
on va donner le nom du module puis indiquer la fonction du module qu'on veut utiliser en mettant un point apres le nom du module :
module.fonction

- module random :

-> randint :
permet de générer un entier aléatoirement au sein d'un interval qu'on défini ( la borne de droite est inclusive. )

>>> import random
>>> print(random.randint(1, 4))
4
>>> print(random.randint(1, 4))
2

- fonction uniform :
nous permet d'avoir une valeur décimale :
>>> print(random.uniform(1, 4))
3.4529285493273734
>>> print(random.uniform(1, 4))
1.9170081114766058

- fonction randrange :
par defaut définit un range en entre 0 et notre range. Attention la valeur de notre range cette fois est exclusive : notre nombre de range ne pourra pas être utilisé par la générateur aleatoire.
4
>>> print(random.randrange(5))
1

on peut donner à randrange un interval et un pas : une valeur qui nous servira à choisir entre les valeurs de notre intervalle par une valeur définie :
>>> print(random.randrange(5,20,5))
10
>>> print(random.randrange(5,20,5))
15
>>> print(random.randrange(5,20,5))
5

ici on veut un nombre aleatoire entre 5 et 20 multiple de 5 


- module os :

on peut l'utiliser par exemple pour créer ou supprimer des dossiers.

ex : on veut creer un sous dossier dans un repertoire connu :

on peut utiliser la fonction path du module os  combinée à la fonction join ( gère les "/" des paths d'arbo. : sous linux/ windows ou mac.)


ex :
tree python_test 
python_test
├── fold1
└── fold2

>>> import os
>>> path = "/tmp/python_test/fold1"
>>> dossier = os.path.join(path, "rep1")
>>> print(dossier)
/tmp/python_test/fold1/rep1

on va maintenant créer le dossier :
on va utiliser la fonction makedirs qui permet de créer des arbo de dossier et sous dossiers

>>> os.makedirs(dossier)
tree python_test                   
python_test
├── fold1
│   └── rep1
└── fold2

on voit que notre sous dossier rep1 du dossier fold1 a été crée
on peut crée des sous arbo :

>>> subpath = "/tmp/python_test/fold2"
>>> subfold = os.path.join(subpath, "sub1", "sub2")
>>> print(subfold)
/tmp/python_test/fold2/sub1/sub2
>>> os.makedirs(subfold)

/tmp  tree python_test    
python_test
├── fold1
│   └── rep1
└── fold2
    └── sub1
        └── sub2

Cette fonction ne crée les dossiers que s'ils n'existent pas sinon on a une erreur.

on peut rajouter un test avec un if avant la creation avec la fonction 'exists'
if ps.path.exists(dossier) 

ou utiliser le param de fonction exist_ok à qui on passe comme valeur True ou False
>>> dossier = os.path.join(path, "rep1")
>>> os.makedirs(dossier, exist_ok=True)
>>> os.makedirs(dossier, exist_ok=False)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "/usr/lib/python3.8/os.py", line 223, in makedirs
    mkdir(name, mode)
FileExistsError: [Errno 17] File exists: '/tmp/python_test/fold1/rep1'

- suppression de repertoires :
removedirs

>>> subpath = "/tmp/python_test/fold2"
>>> subfold = os.path.join(subpath, "sub1", "sub2")
>>> os.removedirs(subfold)
tree python_test          
python_test
└── fold1
    └── rep1
        └── test


on voit que le repertoire fold2 et ses deux sous rep (sub1 et sub2) ont été delete 

>>> help(os.removedirs)
Help on function removedirs in module os:

removedirs(name)
    removedirs(name)

    Super-rmdir; remove a leaf directory and all empty intermediate
    ones.  Works like rmdir except that, if the leaf directory is
    successfully removed, directories corresponding to rightmost path
    segments will be pruned away until either the whole path is
    consumed or an error occurs.  Errors during this latter phase are
    ignored -- they generally mean that a directory was not empty.


= fonction d'aide de module :


help et dir 

- dir permet de faire de l'introspection 

>>> import random
>>> print(dir(random))
['BPF', 'LOG4', 'NV_MAGICCONST', 'RECIP_BPF', 'Random', 'SG_MAGICCONST', 'SystemRandom', 'TWOPI', '_Sequence', '_Set', '__all__', '__builtins__', '__cached__', '__doc__', '__file__', '__loader__', '__name__', '__package__', '__spec__', '_accumulate', '_acos', '_bisect', '_ceil', '_cos', '_e', '_exp', '_inst', '_log', '_os', '_pi', '_random', '_repeat', '_sha512', '_sin', '_sqrt', '_test', '_test_generator', '_urandom', '_warn', 'betavariate', 'choice', 'choices', 'expovariate', 'gammavariate', 'gauss', 'getrandbits', 'getstate', 'lognormvariate', 'normalvariate', 'paretovariate', 'randint', 'random', 'randrange', 'sample', 'seed', 'setstate', 'shuffle', 'triangular', 'uniform', 'vonmisesvariate', 'weibullvariate']


les fonctions qui commencent et finissent par des "__" sont des fonctions privées : dédiées à python
pour les users ont utilise les fonctions sans "__".

- help :
on va afficher directement l'aide sur un module ou une fonction de ce module :

>>> help(random.randint)
Help on method randint in module random:

randint(a, b) method of random.Random instance
    Return random integer in range [a, b], including both end points.

la fonction help va chercher les docstrings (texte qu'on a ecrit pour le module) 


on peut utiliser la fonction pprint du module pprint pour afficher les fonctions d'un module par ordre alphabétique :
>> from pprint import pprint
>>> pprint(dir(random))
['BPF',
 'LOG4',
 'NV_MAGICCONST',
 'RECIP_BPF',
 'Random',
 'SG_MAGICCONST',
 'SystemRandom',
 'TWOPI',
 '_Sequence',
 '_Set',
 '__all__',


= object callable: =

on a des objects qu'on peut appeller en python et d'autres non 

une fonction est callable 
ex: os.mkdirs()
mais pas un module
os() <<< non 

une fonction callable existe pour nous permettre de tester.

>>> import os
>>> callable(os)
False
>>> callable(os.makedirs)
True
>>> 


== listes : ==



>>> import pprint
>>> callable(pprint)
False
>>> from pprint import pprint
>>> callable(pprint)
True


