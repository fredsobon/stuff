# -*- coding: utf-8 -*-

import os


__version__ = '2.0.5'


# Application root path
ROOT_PATH = ''

# Base application directories
CONF_DIR = 'conf'
DATA_DIR = 'var'
SHARE_DIR = 'share'
STATIC_DIR = os.path.join(SHARE_DIR, 'static')
TEMPLATE_DIR = os.path.join(SHARE_DIR, 'templates')
