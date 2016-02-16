#! /bin/sh

# Tous les chemins sont :
#   - soit absolus depuis la racine du systeme de fichiers
#     (commencant par /)
#   - soit relatifs depuis le repertoire personnel de l'utilisateur

# Liste des repertoires a sauvegarder
A_SAUVEGARDER="Documents/ Projets/"

# Repertoire stockant les sauvegarde
REP_SAUVEGARDE="Backup/"

# Prefixe des fichiers de sauvegarde
PREFIXE="sauvegarde"


DATE=$(date +"%Y-%m-%d")
ARCHIVE="${PREFIXE}-${DATE}.tar.bz2"
# Retour dans le repertoire personnel
cd
mkdir -p "${REP_SAUVEGARDE}"
tar -cjf "${REP_SAUVEGARDE}/${ARCHIVE}" ${A_SAUVEGARDER}

