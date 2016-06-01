#!/usr/bin/env python
# -*- coding: utf-8 -*-
'''
Created on 29 nov. 2012

@author: jmmasson
'''

from overview.module.sqlrelay import worker

if __name__ == '__main__':
    worker = worker.Worker('conf/overview.conf')
    worker.run()
