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




