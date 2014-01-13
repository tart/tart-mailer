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

import flask

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from configparser import SafeConfigParser
from libtart.postgres import Postgres

def parseArguments():
    '''Create ArgumentParser instance. Return parsed arguments.'''

    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter, description=__doc__)
    parser.add_argument('--config', default='./mailer.conf', help='configuration file path')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    parser.add_argument('--listen', default='0.0.0.0', help='hostname to listen on')
    parser.add_argument('--port', type=int, default=9000, help='connection port on the web server')

    return parser.parse_args()

app = flask.Flask(__name__)
arguments = parseArguments()
config = SafeConfigParser()
if not config.read(arguments.config):
    raise Exception('Configuration file cannot be read.')
postgres = Postgres(' '.join(k + '=' + v for k, v in config.items('postgres')))

@app.route('/')
def listEmails():
    with postgres:
        return flask.render_template('listEmails.html', emails=postgres.callTable('ListEmails'))

@app.route('/new', methods=['GET', 'POST'])
def newEmail():
    with postgres:
        message = ''
        defaults = {}
        defaults['returnurlroot'] = flask.request.url_root;

        if flask.request.method == 'POST':
            newEmail = postgres.callOneLine('NewEmail', **dict(flask.request.form.items()))
            message = str(newEmail['subscribercount']) + ' email added to the queue.'

        subscriberInfo = postgres.callOneLine('SubscriberInfo')
        return flask.render_template('newEmail.html', message=message, defaults=defaults, **subscriberInfo)

if __name__ == '__main__':
    app.run(host=arguments.listen, port=arguments.port, debug=arguments.debug)

