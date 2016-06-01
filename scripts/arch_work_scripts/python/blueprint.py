# -*- coding: utf-8 -*-

from flask import Blueprint, render_template
from overview.response import make_json_response
from overview.module.sqlrelay import \
    get_configuration, get_status, get_tnsnames


# Create module
sqlrelay = Blueprint('sqlrelay', '__main__', url_prefix='/sqlrelay')


@sqlrelay.route('/')
def index():
    return render_template('sqlrelay.html')


@sqlrelay.route('/settings')
def settings():
    try:
        return make_json_response(get_configuration())
    except Exception as intrpt:
        return make_json_response({"error": "%s" % str(intrpt)}, 500)


@sqlrelay.route('/status/<environment>')
@sqlrelay.route('/status/<environment>/<server>')
def status(environment, server=None):
    try:
        if server:
            return make_json_response(get_status(environment, server))
        else:
            return make_json_response(get_status(environment))
    except Exception as intrpt:
        return make_json_response({"error": "%s" % str(intrpt)}, 500)


@sqlrelay.route('/tnsnames/<environment>/<server>')
def tnsnames(environment, server=None):
    try:
        return make_json_response(get_tnsnames(environment, server))
    except Exception as intrpt:
        return make_json_response({"error": "%s" % str(intrpt)}, 500)


@sqlrelay.route('/configuration/<environment>/<server>')
def configuration(environment, server):
    try:
        return make_json_response(get_configuration(environment, server))
    except Exception as intrpt:
        return make_json_response({"error": "%s" % str(intrpt)}, 500)
