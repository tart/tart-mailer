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
postgres = Postgres('')

@app.route('/')
def listEmails():
    with postgres:
        return flask.render_template('listEmails.html', emails=postgres.callTable('ListEmails'),
                                     outgoingServers=postgres.callTable('ListOutgoingServers'))

@app.route('/new', methods=['GET', 'POST'], defaults={'action': 'save'})
@app.route('/<int:emailId>', methods=['GET', 'POST'], defaults={'action': 'save'})
@app.route('/sendTest', methods=['POST'], defaults={'action': 'sendTest'})
@app.route('/removeTest', methods=['POST'], defaults={'action': 'removeTest'})
@app.route('/send', methods=['POST'], defaults={'action': 'send'})
def newEmail(emailId=None, action=None):
    with postgres:
        newForm = {}

        if flask.request.method == 'POST':
            form = dict((k, v) for k, v in flask.request.form.items() if k[-2:] != '[]' and v != '')
            emailId = form.get('emailid')
            newForm['action'] = action

            if action == 'save':
                if not emailId: 
                    email = postgres.callOneLine('NewEmail', **form)
                    if email:
                        newForm['message'] = 'Email created.'
                        emailId = email['id']
                else:
                    if postgres.callOneLine('ReviseEmail', **form):
                        newForm['message'] = 'Email updated.'
                    else:
                        newForm['message'] = 'Email could not found.'
            else:
                if action == 'sendTest':
                    subscriberCount = postgres.callOneCell('SendTestEmail', **form)
                    if subscriberCount:
                        newForm['message'] = 'Test email added to the queue.'
                    else:
                        newForm['message'] = 'Subscriber could not found.'

                elif action == 'removeTest':
                    subscriberCount = postgres.callOneCell('RemoveTestEmailSend', **form)
                    newForm['message'] = str(subscriberCount) + ' test email removed.'

                elif action == 'send':
                    form['locales'] = [None if v == 'None' else v for v in flask.request.form.getlist('locales[]')]
                    subscriberCount = postgres.callOneCell('SendEmail', **form)
                    newForm['message'] = str(subscriberCount) + ' email added to the queue.'

        if emailId:
            newForm['email'] = postgres.callOneLine('GetEmail', emailId)
            newForm['subscriberlocalestats'] = postgres.callTable('SubscriberLocaleStats', emailId)
            newForm['subscribercount'] = sum(s['count'] - s['sendcount'] for s in newForm['subscriberlocalestats'])
        else:
            newForm['email'] = {'draft': True, 'returnurlroot': flask.request.url_root}
            newForm['exampleproperties'] = postgres.callOneLine('SubscriberExampleProperties')
        newForm['outgoingServers'] = postgres.callOneCell('OutgoingServerNames')

        return flask.render_template('email.html', **newForm)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=True)

