#!/usr/bin/env python
# -*- coding: utf-8 -*-
##
# Tart Mailer
#
# Copyright (c) 2013, Tart İnternet Teknolojileri Ticaret AŞ
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby
# granted, provided that the above copyright notice and this permission notice appear in all copies.
#
# The software is provided "as is" and the author disclaims all warranties with regard to the software including all
# implied warranties of merchantability and fitness. In no event shall the author be liable for any special, direct,
# indirect, or consequential damages or any damages whatsoever resulting from loss of use, data or profits, whether
# in an action of contract, negligence or other tortious action, arising out of or in connection with the use or
# performance of this software.
##

import os
import flask
import werkzeug
import json
import datetime
import functools

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart import collections
from libtart import postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))

class NotAllowed(werkzeug.exceptions.Gone): pass

class JSONEncoder(flask.json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime.datetime):
            return obj.isoformat() 

        return flask.json.JSONEncoder.default(self, obj)

app.json_encoder = JSONEncoder

##
# Routes
#
# API only accept and always return JSON objects. Array or primitive types are not acceptable on the top level.
##

def databaseOperationViaAPI(operation):
    """Wrapper for the API operations. Execute queries in a single database transaction. Authenticate senders.
    Validate the request. Update kwargs with JSON POST data."""

    @functools.wraps(operation)
    def wrapped(**kwargs):
        if flask.request.method in ('POST', 'PUT'):
            if flask.request.headers['Content-Type'] != 'application/json':
                raise werkzeug.exceptions.BadRequest('Content-Type must be application/json')

            if not isinstance(flask.request.json, dict):
                raise werkzeug.exceptions.BadRequest('data must be a JSON object')

        if not flask.request.authorization:
            raise werkzeug.exceptions.Unauthorized('authentication required')

        with postgres.connection():
            if not postgres.connection().call('SenderAuthenticate', flask.request.authorization):
                raise werkzeug.exceptions.Unauthorized('authentication failed')

            data = collections.OrderedCaseInsensitiveDict(kwargs)
            data['fromAddress'] = flask.request.authorization.username
            if flask.request.json:
                for key in flask.request.json.keys():
                    if key in data:
                        raise werkzeug.exceptions.BadRequest(key + ' already defined')
                data.update(flask.request.json)

            response = operation(data)
            assert isinstance(response, dict)

            return flask.jsonify(response)

    return wrapped

@app.route('/sender', methods=['GET'])
@databaseOperationViaAPI
def getSender(data):
    return postgres.connection().selectOne('Sender', data)

@app.route('/email', methods=['POST'])
@databaseOperationViaAPI
def addEmail(data):
    return postgres.connection().insert('NestedEmail', data)

@app.route('/email/list', methods=['GET'])
@databaseOperationViaAPI
def listEmails(data):
    return paginate('NestedEmail', data)

@app.route('/email/<int:emailId>', methods=['GET'])
@databaseOperationViaAPI
def getEmail(data):
    return postgres.connection().selectOne('NestedEmail', data)

@app.route('/email/<int:emailId>/variation', methods=['POST'])
@databaseOperationViaAPI
def addEmailVariation(data):
    return postgres.connection().insert('EmailVariation', data)

@app.route('/email/<int:emailId>/variation/<int:variationId>', methods=['GET'])
@databaseOperationViaAPI
def getEmailVariation(data):
    return postgres.connection().selectOne('EmailVariation', data)

@app.route('/subscriber', methods=['POST'])
@databaseOperationViaAPI
def addSubscriber(data):
    return postgres.connection().insert('Subscriber', data)

@app.route('/subscriber/list', methods=['GET'])
@databaseOperationViaAPI
def listSubscribers(data):
    return paginate('Subscriber', data)

@app.route('/subscriber/<string:toAddress>', methods=['GET'])
@databaseOperationViaAPI
def getSubscriber(data):
    return postgres.connection().selectOne('Subscriber', data)

@app.route('/subscriber/<string:toAddress>', methods=['PUT'])
@databaseOperationViaAPI
def upsertSubscriber(data):
    try:
        return postgres.connection().updateOne('Subscriber', data, data.subset('fromAddress', 'toAddress'))
    except postgres.NoRow:
        return postgres.connection().insert('Subscriber', data)

@app.route('/subscriber/<string:toAddress>/send', methods=['POST'])
@databaseOperationViaAPI
def sendToSubscriber(data):
    try:
        return postgres.connection().call('SendToSubscriber', data)
    except postgres.NoRow:
        raise NotAllowed('cannot send to this address')

@app.route('/email/send/list', methods=['GET'])
@app.route('/email/<int:emailId>/send/list', methods=['GET'])
@app.route('/subscriber/<string:toAddress>/send/list', methods=['GET'])
@databaseOperationViaAPI
def listEmailSend(data):
    return paginate('NestedEmailSend', data)

def paginate(tableName, whereConditions):
    response = {'limit': flask.request.args.get('limit', 100)} # 100 is the default limit.
    if 'offset' in flask.request.args:
        response['offset'] = flask.request.args['offset']
    response['records'] = postgres.connection().select(tableName, whereConditions, **response)
    return response

##
# Errors
#
# Only client errors (4xx) are catch and returned in a standart JSON object. Server errors (5xx) left untouched.
##

@app.errorhandler(401)
def authenticationRequired(error):
    """Add WWW-Authenticate header to the 401 response to enable basic HTTP authentication."""

    return (flask.jsonify({'error': error.description, 'type': type(error).__name__}), 401,
            {'WWW-Authenticate': 'Basic realm="Sender Authentication"'})

def clientError(error):
    return flask.jsonify({'error': error.description, 'type': type(error).__name__}), error.code

# A decorator should be use instead of this: @app.errorhandler(werkzeug.exceptions.HTTPException)
# Currently, it is not possible because of a design flaw in Flask. I hope it will be fixed
# by: https://github.com/mitsuhiko/flask/pull/839
app.error_handler_spec[None].update(dict((code, clientError) for code in range(400, 499) if code != 401))

@app.errorhandler(postgres.PostgresError)
def postgresError(error):
    return flask.jsonify({'error': str(error), 'type': type(error).__name__, 'details': error.details()}), 406

##
# HTTP server for development
#
# Do not use it on production.
##
if __name__ == '__main__':
    postgres.debug = True
    app.run(port=8080, debug=True)
