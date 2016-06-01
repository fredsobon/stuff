#!/usr/bin/env python
# -*- coding: utf-8 -*-

import ldap
import re
import json
import requests
import codecs
import os

JIRA_API_BASE = 'https://jira.e-merchant.com/rest/api/2'
JIRA_USER_LOGIN = 'jira-autoimport'
JIRA_USER_PASSWORD = 'xPj4bkVviXij9uUP'

LDAP_SERVER = 'ldap://dcvitry.server.office.prod.vit.e-merchant.net:389'
USER = 'cn=ldap_connex,dc=groupe-llp,dc=com'
PASSWORD = 'G008eede'
CONNEXION = ldap.initialize(LDAP_SERVER)
CONNEXION.simple_bind_s(USER, PASSWORD)
BASE = 'OU=Siege Grande Armee,DC=groupe-llp,DC=com'

MAIL = ""
DISPLAYNAME = ""
SAMACCOUNTNAME = ""

def main():
	print("Connecté au serveur.\n")
	print("Recherche en cours..\n")

	recherche = CONNEXION.search_s(BASE, ldap.SCOPE_SUBTREE, '(&(objectClass=user)(objectClass=person))', ['sAMAccountName', 'displayName', 'mail'])

	for i in recherche:
		if not re.search('(OU=Computers|OU=VLAN 21 - SALLES DE REUNION|cn=formation|cn=test_imacros|CN=rhfah|CN=user test2|\
			CN=serviceclients|CN=mediation|CN=BteMel Test|CN=blog|CN=IT Prod Calendar|CN=mail.test|CN=pixmania-concours|CN=Order \
			Validation|CN=IPadmin|CN=AP-Transaction|CN=sapadmin|CN=masterdata|CN=bap-expenses|CN=sav-expenses|CN=ap-transport|\
			CN=ap-expenses|CN=traders.invoices|CN=pixmania.invoices|CN=ap-merchandise|CN=RFC|CN=Cotations_PIXPRO|CN=PXP|CN=TALEND|\
			CN=testjessy|CN=Test Script2|CN=Test Script1|CN=sales_warning|CN=Test TEST|CN=emailing_pixmania|CN=glpi3 glpi3|\
			CN=bureautest|CN=bpi|CN=glpi2|OU=A CLASSER|CN=pixplace_fr|CN=baltic|CN=scandinavia|CN=monitoringbdd|CN=Brno Visit|\
			CN=Services Clients|CN=bes|CN=Blogdephil|CN=Edifixio|CN=Servicio de Atención al Cliente|CN=Vision|CN=mitel|\
			CN=support_pixvalley_bby|CN=Serviço de Apoio a Clientes|CN=vlan11|CN=PreventionHermes|CN=iMacroMOA|CN=astreinte1|\
			CN=testuca|CN=blue1|CN=partage|CN=vlan03|CN=RHPIX|CN=pixplace france|CN=annulationoney|CN=pixmaniapro|CN=BI_files|\
			CN=Support_Monitoring|OU=Computer|CN=integration_contenus|CN=loc_OP|CN=loc_SIS|CN=loc_mail|CN=support_dsg_bby|\
			CN=Visite Medicale|CN=Testing|CN=testjira|CN=scancompta|CN=InvoicingDsgPixmania|CN=vlan17|CN=Eclipse1|CN=vlan15|\
			CN=Achatshp|CN=Translate|CN=Opé_co|CN=Mainsecurite|CN=FacebookFR|CN=Dsgproductinfo|CN=CalendrierBureautique|\
			CN=outils-pixpro|CN=Cepixmania|CN=Ce-pixmania|CN=Photoshop PHOTOSHOP|CN=Help|CN=UK-PixPlace|CN=BI|CN=info_pixplace|\
			CN=astreinte_JD|CN=astreinte_BC|CN=nagios nagios|CN=modif_tauxdechange|CN=vlan06|CN=astreinte_bi|CN=Transport|\
			CN=Laptop TRANSPORT|CN=ar)', i[0], re.I|re.M):
				try:
					MAIL = (i)[1]['mail']
					DISPLAYNAME = (i)[1]['displayName']
					SAMACCOUNTNAME = (i)[1]['sAMAccountName']

					#post_add_groups(SAMACCOUNTNAME[0])
					try:
						#print '{0}'.format(SAMACCOUNTNAME[0])
					
						# affiche infos user dans jira
						#user = get_user(SAMACCOUNTNAME[0])
						#if user is not None:
						#	from pprint import pprint
						#	pprint (user)

						# ajout comptes AD dans jira (si non présents)
						post_user(SAMACCOUNTNAME[0], MAIL[0], DISPLAYNAME[0])
						post_add_groups(SAMACCOUNTNAME[0])
					except:
						pass
				except KeyError:
					pass
		#for x in 'abcdefghijklmnopqrstuvwxyz':
			#search_user_inactive(x)

def get_user(name):
	req = requests.get(url='%s/user' % JIRA_API_BASE, auth=(JIRA_USER_LOGIN, JIRA_USER_PASSWORD), params={
		u'username': name
		})
	if req.status_code == 404:
		return None
	return json.loads(req.content)

def post_user(name, mail, fullname):
    headers = {'content-type': 'application/json'}
    data = json.dumps({u'name': name,'groups': 'jira-users', 'active': True, u'emailAddress': mail,
     u'displayName': fullname})
    req = requests.post(url='%s/user' % JIRA_API_BASE, auth=(JIRA_USER_LOGIN, JIRA_USER_PASSWORD), headers=headers, data=data)
    print(req.text)
    print(req.content)

def post_add_groups(name):
    for i in ['Pixmania/E-Merchant users','jira-users']:
        headers = {'content-type': 'application/json'}
        data = json.dumps({u'name': name})
        req = requests.post(url='%s/group/user' % JIRA_API_BASE, auth=(JIRA_USER_LOGIN, JIRA_USER_PASSWORD), params={
            u'groupname': i }, headers=headers, data=data)
        print(req.content)
        print(req.text)

def search_user_inactive(name):
	req = requests.get(url='%s/user/search' % JIRA_API_BASE, auth=(JIRA_USER_LOGIN, JIRA_USER_PASSWORD), params={
		u'username': name,  'startAt': 0, 'maxResults': 1000, 'includeInactive': True, 'includeActive': False
		})
	individus = json.loads(req.content)
	for i in individus:	
		liste = dict(i)
		print(liste)['name']
		try:
			with codecs.open("/tmp/liste_utilisateurs_desactives", 'a', encoding='utf-8') as desactives:
				desactives.write(liste[u'name'])
				desactives.write('\n')
		except UnicodeEncodeError:
			pass

def post_del_groups(name):
    for i in ['Pixmania/E-Merchant users','jira-users']:
        headers = {'content-type': 'application/json'}
        data = json.dumps({u'name': name})
        req = requests.post(url='%s/group/user' % JIRA_API_BASE, auth=(JIRA_USER_LOGIN, JIRA_USER_PASSWORD), params={
            u'groupname': i, u'username': name }, headers=headers, data=data)
        print(req.content)
        print(req.text)

if __name__ == '__main__':
	main()

exit(0)
