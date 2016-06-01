# -*- coding: utf-8 -*-

from flask import Response, json


def make_json_response(data, status=200):
    try:
        json.encoder.FLOAT_REPR = lambda a: format(a, '.2f')
    except:
        pass

    response = Response(status=status)
    response.headers['Content-Type'] = 'application/json; charset=utf-8'
    response.data = json.dumps(data)

    return response
