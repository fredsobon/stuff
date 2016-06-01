#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""script de supervision des WINDOWS"""

import netsnmp
import argparse
import sys
import re
import math

# conversion octets(bytes) en gibioctet Gio ou tebioctet Tio
# http://fr.wikipedia.org/wiki/Octet

# OID
CPU = '.1.3.6.1.2.1.25.3.3.1.2'
HDD_DESC = '.1.3.6.1.2.1.25.2.3.1.3'
HDD_ALLOC_UNIT = '.1.3.6.1.2.1.25.2.3.1.4'
HDD_SIZE = '.1.3.6.1.2.1.25.2.3.1.5'
HDD_USED = '.1.3.6.1.2.1.25.2.3.1.6'
UNKNOWN = 3
CRITICAL = 2
WARNING = 1

# valeur a ajouter si snmp renvoie une valeur negative
int32_MaxValue = math.pow(2, 32)


liste_processeurs = []
liste_volumes = []
unites_allocation_disque = []
allocation = []

parser = argparse.ArgumentParser()
parser.add_argument("-H", "--HOST" , help="host target", action='store')
args = parser.parse_args()

session = netsnmp.Session( DestHost=args.HOST, Version=2, Community='pixro',
        UseNumeric=1 )

def main():
	compteur = 0
	compteur_critical = 0
	compteur_warning = 0
	nbre_proc()
	#print("{} processeurs").format(len(liste_processeurs))
	if len(liste_processeurs) == 0:
		exit(3)
	nbre_volumes()
	#print("{} volumes").format(len(liste_volumes))
	#print("liste volumes: %s " % liste_volumes)
	for i in liste_volumes:
		try:
			taille_volume(compteur)
			#print("capacite:", capacite)
			allocation_units(compteur)
			#print("allocation", allocation)
			espace_utilise = ((float(utilisation_volume(compteur) / float(taille_volume(compteur))))) * 100
			#print("TAILLE DISQUE:", capacite * float(allocation))
			#print("ESPACE UTILISE:", utilisation * float(allocation))
			if espace_utilise > 90:
				print("CRITICAL {0} {1:.1f} %".format(i, espace_utilise))
				compteur_critical += 1
			elif espace_utilise > 80:
				print(" WARNING {0} {1:.1f} %".format(i, espace_utilise))
				compteur_warning += 1
			compteur += 1
		except ZeroDivisionError:
			pass
	if compteur_critical > 0:
		exit(2)
	elif compteur_warning > 0:
		exit(1)
	else:
		print("OK")
	exit(0)

def taille_volume(compteur):
	"""taille du volume"""
	global capacite
	capacite = session.walk(netsnmp.VarList( netsnmp.Varbind(HDD_SIZE) ))[compteur]
	capacite=int(capacite)
	if capacite < 0:
		capacite=int32_MaxValue - math.fabs(capacite)
	return capacite

def utilisation_volume(compteur):
	"""espace consomme sur le volume"""
	global utilisation
	utilisation = session.walk(netsnmp.VarList( netsnmp.Varbind(HDD_USED) ))[compteur]
	utilisation=int(utilisation)
	if utilisation < 0:
		utilisation=int32_MaxValue - math.fabs(utilisation)
	return utilisation

def nbre_volumes():
	"""liste des volumes sans la référence à la mémoire"""
	LISTE_VOLUME = session.walk(netsnmp.VarList( netsnmp.Varbind(HDD_DESC) ))
	for i in range(len(LISTE_VOLUME)):
		if not re.search('emory', LISTE_VOLUME[i]):
			liste_volumes.append(LISTE_VOLUME[i])
	return liste_volumes

def nbre_proc():
	"""nombre de processeurs"""
	charge_processeur = session.walk(netsnmp.VarList( netsnmp.Varbind(CPU) ))
	for i in range(len(charge_processeur)):
		liste_processeurs.append(charge_processeur[i])
	return liste_processeurs

def allocation_units(compteur):
	"""unite allocation des disques"""
	global allocation
	allocation = session.walk(netsnmp.VarList( netsnmp.Varbind(HDD_ALLOC_UNIT )))[compteur]
	#print("unites allocation disque:", allocation)
	return allocation

main()
