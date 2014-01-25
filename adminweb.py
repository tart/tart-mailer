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
import os

from libtart.postgres import Postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))

@app.route('/')
def listEmails():
    with Postgres('') as postgres:
        return flask.render_template('listEmails.html', emails=postgres.callTable('ListEmails'),
                                     outgoingServers=postgres.callTable('ListOutgoingServers'),
                                     incomingServers=postgres.callTable('ListIncomingServers'))

@app.route('/new', methods=['GET', 'POST'], defaults={'action': 'save'})
@app.route('/<int:emailId>', methods=['GET', 'POST'], defaults={'action': 'save'})
@app.route('/sendTest', methods=['POST'], defaults={'action': 'sendTest'})
@app.route('/send', methods=['POST'], defaults={'action': 'send'})
def newEmail(emailId=None, action=None):
    with Postgres('') as postgres:
        message = ''

        if flask.request.method == 'POST':
            form = dict((k, v) for k, v in flask.request.form.items() if k[-2:] != '[]' and v != '')
            emailId = form.get('emailid')

            if action == 'save':
                if not emailId: 
                    email = postgres.callOneLine('NewEmail', **form)
                    if email:
                        message = 'Email created.'
                        emailId = email['id']
                else:
                    if postgres.callOneLine('ReviseEmail', **form):
                        message = 'Email updated.'
                    else:
                        message = 'Email could not found.'
            else:
                if action == 'sendTest':
                    if postgres.callOneCell('SendTestEmail', **form):
                        message = 'Test email added to the queue.'
                    else:
                        message = 'Test email could not send. Subscriber may not be in the database.'

                elif action == 'send':
                    form['locales'] = [None if v == 'None' else v for v in flask.request.form.getlist('locales[]')]
                    subscriberCount = postgres.callOneCell('SendEmail', **form)
                    message = str(subscriberCount) + ' email added to the queue.'

        if emailId:
            email = postgres.callOneLine('GetEmail', emailId)
            email['previewurl'] = postgres.callOneCell('PreviewEmailURL', emailId)

            subscriberLocaleStats = postgres.callTable('SubscriberLocaleStats', emailId)
            email['subscriberlocalestats'] = subscriberLocaleStats
            email['subscribercount'] = sum(s['count'] - s['sendcount'] for s in subscriberLocaleStats)
        else:
            parts = parseURL(flask.request.url_root)
            email = {'draft': True, 'returnurlroot': parts['protocol'] + '//' + parts['root'] + '/'}

        email['exampleproperties'] = postgres.callOneCell('SubscriberExampleProperties')
        email['outgoingservernames'] = postgres.callOneCell('OutgoingServerNames')
        email['incomingservers'] = postgres.callTable('ListIncomingServers')

        return flask.render_template('email.html', action=action, message=message, email=email)

def parseURL(uRL):
    parts = {}
    parts['protocol'], address = uRL.split('//')
    parts['root'], parts['uRI'] = address.split('/', 1)
    if ':' in parts['root']:
        parts['root'], parts['port'] = parts['root'].split(':')
    return parts

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=True)

