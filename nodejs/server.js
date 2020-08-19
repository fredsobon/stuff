
// on defini une variable qui sera le chargement du module nodejs http
var http = require('http');
// on defini une variable server qui sera le resultat de la creation de notre serveur avec l'objet http et la methode createServer qui prenne en argument une fonction de callback anonyme qui prend des arguments function(req, res) . req va contenir toutes les infos que le visiteur a appellé : nom de la page, params, valeur de formulaire ...res : object qu'on va générer pour donner un retour au user: en général une page html. Ici on va simplement renvoyer un code http 200 et un message de type "'Hello from boogieland !'"
// il s'agit d'une fonction qui sera executée quand un client se connectera au site 
var server = http.createServer(function(req, res) {
res.writeHead(200, {"Content-Type": "text/html"} );
res.write('<!DOCTYPE html>'+
'<html>'+
' <head>'+
' <meta charset="utf-8" />'+
' <title> Node.js !</title>'+
' </head>'+
' <body>'+
' <p>hey <strong>get it down!</strong> !</p>'+
' </body>'+
'</html>');        
res.end('<h2>Hello from boogieland !</h2>');
});
server.listen(8080);



