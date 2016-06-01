#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ft=python

from overview.app import app

if __name__ == '__main__':
    app.secret_key = 'devel'
    app.run(debug=True)
