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
import json
import datetime
import functools

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres, PostgresNoRow, PostgresError

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))
postgres = Postgres()

class JSONEncoder(flask.json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime.datetime):
            return obj.isoformat() 

        return flask.json.JSONEncoder.default(self, obj)

app.json_encoder = JSONEncoder

def databaseOperationViaAPI(operation):
    """Wrapper for the API operations. Execute queries in a single database transaction. Authenticate senders.
    Send a 401 response to enable basic HTTP authentication if required. Update kwargs with JSON POST data.
    Return proper errors."""

    @functools.wraps(operation)
    def wrapped(*args, **kwargs):
        try:
            with postgres:
                if flask.request.authorization:
                    if postgres.exists('Sender', {'fromAddress': flask.request.authorization.username}):
                        kwargs.update(flask.request.json)
                        kwargs['fromAddress'] = flask.request.authorization.username

                        return flask.jsonify(operation(*args, **kwargs))

                response = {'error': 'authentication required', 'type': 'Authentication'}
                return flask.jsonify(response), 401, {'WWW-Authenticate': 'Basic realm="Sender Authentication"'}

        except StandardError as error:
            response = {'error': str(error), 'type': type(error).__name__}
            if isinstance(error, PostgresError):
                response['details'] = error.details()

            return flask.jsonify(response), 400

    return wrapped

##
# Routes
##

@app.route('/subscriber', methods=['POST'])
@databaseOperationViaAPI
def addSubscriber(**kwargs):
    return postgres.insert('Subscriber', kwargs)

@app.route('/subscriber/<string:toaddress>', methods=['PUT'])
@databaseOperationViaAPI
def upsertSubscriber(**kwargs):
    try:
        whereConditions = dict((k, v) for k, v in kwargs.items() if k.lower() in ('fromaddress', 'toaddress'))
        setColumns = dict((k, v) for k, v in kwargs.items() if k not in whereConditions)

        return postgres.update('Subscriber', setColumns, whereConditions, table=False)
    except PostgresNoRow:
        return postgres.insert('Subscriber', kwargs)

@app.errorhandler(404)
def notFound(error):
    return flask.jsonify({'error': 'not found', 'type': 'General'}), 404

if __name__ == '__main__':
    Postgres.debug = True
    app.run(host='0.0.0.0', port=8080, debug=True)
