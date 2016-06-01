#!/usr/bin/python -u
# -*- coding: utf-8 -*-
# vim: ft=python ts=4 sw=4 et

import requests,sys

sitelist = [ 'www.pixmania', 'online.carrefour.fr', 'www.celio.com', 'www.pixmania-pro.com', 'www.apc.fr', 'www.monnierfreres.fr', 'www.pixdeals.fr']
tld= ['be', 'co.uk', 'de', 'dk', 'es', 'fi', 'fr', 'ie', 'it', 'nl', 'no', 'pl', 'pt', 'se' ]
err_lst = []


def getReturnCode( url ):
        r = requests.get(url)
        return str(r.status_code)

for site in sitelist:
    for i in 'http://', 'https://':
        if site == 'www.pixmania' and i == 'https://':
            for pays in tld:
                url = i+site+'.'+pays+'/secure/'
                if getReturnCode( url ) != '200':
                        err_lst.append(i+site+'.'+pays)
        elif site == 'www.pixmania' and i == 'http://':
                for pays in tld:
                        url = i+site+'.'+pays
                        if not getReturnCode( url ) == '200':
                                err_lst.append(i+site+'.'+pays)
        elif i == 'https://' and ( 'pixmania-pro' or 'monnier' or 'apc' in site ):
            break
        elif i == 'https://':
                url = i+site+'/secure/'
                if not  getReturnCode( url ) == '200':
                        err_lst.append(i+site)
        else:
            url = i+site
            if not getReturnCode( url ) == '200':
                err_lst.append(i+site)

if len(err_lst) != 0:
    print("WARNING: Redirection detected for: ")
    for site in err_lst:
        print site
    sys.exit(1)
else:
    print("OK")
    sys.exit(0)

