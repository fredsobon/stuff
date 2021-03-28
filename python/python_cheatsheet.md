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

## converstion de type d'objet 

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

