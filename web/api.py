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

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres, PostgresError

class JSONEncoder(flask.json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, datetime.datetime):
            return obj.isoformat() 

        return flask.json.JSONEncoder.default(self, obj)

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))
app.json_encoder = JSONEncoder

def databaseOperationViaAPI(operation):
    def wrapped(*args, **kwargs):
        try:
            return flask.jsonify(operation(*args, **kwargs))
        except StandardError as error:
            response = {'error': str(error), 'type': type(error).__name__}
            if isinstance(error, PostgresError):
                response['details'] = error.details()

            return flask.jsonify(response), 400

    return wrapped

@app.route('/subscriber', methods=['POST'])
@databaseOperationViaAPI
def addSubscriber():
    with Postgres() as postgres:
        return postgres.insert('Subscriber', flask.request.json)

@app.errorhandler(404)
def notFound(error):
    return flask.jsonify({'error': 'Not found'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
