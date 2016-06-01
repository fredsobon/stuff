#!/usr/bin/env python
# -*- coding: utf-8 -*-

import lxml.html
import pycurl
import StringIO
import sys

from optparse import OptionParser
from lxml.cssselect import CSSSelector

SOURCE_URL = 'http://www.dell.com/support/troubleshooting/us/en/555/TroubleShooting/Display_Warranty_Tab'
COOKIE = 'OLRProduct=%s|'

def get_text(element):
    text = element.text if element.text else ''

    for child in element.getchildren():
        text += get_text(child)

    return text

def get_warranty(service_tag):
    data = StringIO.StringIO()

    curl = pycurl.Curl()
    curl.setopt(pycurl.URL, SOURCE_URL)
    curl.setopt(curl.WRITEFUNCTION, data.write)
    curl.setopt(pycurl.COOKIE, COOKIE % service_tag.lower())
    curl.perform()

    html = lxml.html.fromstring(data.getvalue())

    selector = CSSSelector('table.uif_table tr')

    warranty = list()

    for element in selector(html):
        row = map(get_text, element.getchildren())

        warranty.append(row)

    return warranty

if __name__ == '__main__':

    PARSER = OptionParser(usage = 'Usage: %prog -t|-l <service tag>')
    PARSER.add_option('-t', '--table', dest = 'table', default=False,
        action='count', help='print warranty in a pretty table')
    PARSER.add_option('-l', '--line', dest = 'line', default=False,
        action='count', help='print warranty in one line')

    (OPTIONS, ARGS) = PARSER.parse_args()

    if len(ARGS) != 1:
        PARSER.error('service tag is missing.')

    WARRANTY = get_warranty(ARGS[0])
    if not WARRANTY:
        PARSER.error('invalid service tag.')

    if OPTIONS.table:
        from prettytable import PrettyTable

        TABLE = None

        for ROW in WARRANTY:
            if not TABLE:
                TABLE = PrettyTable(ROW)
                TABLE.set_field_align(ROW[0], 'l')
                TABLE.set_field_align(ROW[1], 'l')
                TABLE.set_field_align(ROW[-1], 'r')
            else:
                TABLE.add_row(ROW)

        print(TABLE)

    elif OPTIONS.line:
        import datetime

        DATE = list()

        for ROW in WARRANTY:
            if ROW[0] == 'Services':
                continue

            for i in [2, 3]:
                month, day, year = ROW[i].split('/')
                DATE.append(datetime.date(int(year), int(month), int(day)))

        DATE.sort()

        print('%s;%s;%s' % (ARGS[0], DATE[0], DATE[-1]))

    else:
        PARSER.error('service tag is missing.')

    sys.exit(0)
