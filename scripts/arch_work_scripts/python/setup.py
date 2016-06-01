#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
sys.path.insert(0, '.')

import os

# from xxx import __version__
from setuptools import find_packages, setup


# data_files = [('bin', ['scripts/xchgctl'])]
data_files = []

for root, dirs, files in os.walk('scripts'):
    data_files.append((os.path.join('bin', root[7:]), [os.path.join(root, x) for x in files]))

setup(
    name='dataxchg',
    version='1.2.6',
    author='Jean-Michel Masson',
    author_email='jmmasson@e-merchant.com',
    url='http://www.e-merchant.com/',
    description='dataxchg',
    packages=find_packages(),
    data_files=data_files,
    zip_safe=False,
    install_requires=[],
)
