# -*- coding: utf-8 -*-

import ConfigParser
import os
import stat

from flask import Flask, g, redirect, url_for
from overview import CONF_DIR, DATA_DIR, ROOT_PATH, STATIC_DIR, TEMPLATE_DIR
from overview.module.jira.blueprint import jira
from overview.module.nagios.blueprint import nagios
from overview.module.rman.blueprint import rman
from overview.module.sqlrelay.blueprint import sqlrelay
from werkzeug.contrib.cache import FileSystemCache


# Create application
app = Flask(__name__, static_folder=STATIC_DIR, template_folder=TEMPLATE_DIR)
app.root_path = ROOT_PATH
app.debug = True

# Load configuration
file_path = os.path.join(CONF_DIR, 'overview.conf')

if os.path.exists(file_path):
    # Check secret key file permissions
    mode = os.stat(file_path).st_mode

    if mode & stat.S_IRWXU != 384 or mode & stat.S_IRWXG != 0 or mode & stat.S_IRWXO != 0:
        raise Exception("%s file permissions should be 600\n" % file_path)

    parser = ConfigParser.ConfigParser()
    parser.read([file_path])

    # Set application secret key
    app.secret_key = parser.get('main', 'secret_key')
    parser.remove_option('main', 'secret_key')

    # Set application settings parser
    app.settings = parser

# Register modules
app.register_blueprint(jira)
app.register_blueprint(nagios)
app.register_blueprint(rman)
app.register_blueprint(sqlrelay)


@app.before_request
def before_request():
    g.cache = FileSystemCache(os.path.join(DATA_DIR, 'cache'))


@app.teardown_request
def teardown_request(e):
    if hasattr(g, 'cache'):
        del g.cache


@app.route('/')
def index():
    return redirect(url_for('nagios.index'))
