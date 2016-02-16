#! /bin/sh

# Creation d'un sous-repertoire representant le futur
# repertoire /usr/local/bin de la cible d'installation
rm -rf usr/
mkdir -p usr/local/bin/

cp *.sh usr/local/bin/

# Creation d'une archive binaire compressee temporaire
tar --owner=root --group=root -czf "install.tar.gz" usr/ || exit 1

# Creation d'un script install.sh
rm -f "install.sh"
cat > "install.sh" <<-EOF
	#! /bin/sh
	
	# Verification que l'utilisateur soit bien root
	i=\$(id -u)
	if [ \$? -ne 0 ]; then exit 1; fi
	if [ "\$i" -ne 0 ]
	then
	  echo "L'installation doit se faire sous root" >&2
	  exit 2
	fi
EOF

cat >> "install.sh" <<-EOF
	# Ajouter ici les eventuelles actions avant
	# deploiement de l'archive (sauvegarde des fichiers,
	# precedents, creation d'utilisateur, etc.)
EOF

cat >> "install.sh" <<-EOF
	# Extraction du fichier d'archive dans le script
	base64 -d > /tmp/install.tar.gz <<-END
EOF

# Integration de l'archive dans le script
base64 "install.tar.gz" >> "install.sh"

cat >> "install.sh" <<-EOF
	END
	if [ \$? -ne 0 ]; then exit 3; fi

	# Decompression de l'archive
	cd /
	tar xzf /tmp/install.tar.gz || exit 4
	rm -f /tmp/install.tar.gz
EOF

cat >> "install.sh" <<-EOF
	# Ajouter ici les eventuelles actions apres
	# deploiement de l'archive (liens symboliques, etc.)
EOF

# Effacer l'archive et le sous-repertoire temporaires
rm -f install.tar.gz
rm -rf usr/

# Rendons le script executable
chmod 755 "install.sh"

