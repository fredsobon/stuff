#!/usr/bin/env python
# -*- coding: utf-8 -*-

# basic script in order to retrieve all records from a table called 'users' from a db called 'test'

import sqlite3

conn = sqlite3.connect('db.db')
cursor = conn.cursor()
cursor.execute("""SELECT * FROM users""")
rows = cursor.fetchall()
for row in rows:
    print('{0} : {1} - {2}'.format(row[0], row[1], row[2]))
conn.close()


