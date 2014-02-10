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
postgres = Postgres()

@app.route('/')
def listEmails():
    with postgres:
        return flask.render_template('listEmails.html', emails=postgres.select('EmailDetail'),
                                     outgoingServers=postgres.select('OutgoingServer'),
                                     incomingServers=postgres.select('IncomingServer'))

@app.route('/email')
@app.route('/email/<int:id>')
def email(id=None, **kwargs):
    with postgres:
        if id:
            email = postgres.select('Email', {'id': id}, table=False)
            email['variations'] = postgres.select('EmailVariation', {'emailid': id})

            subscriberLocaleStats = postgres.call('SubscriberLocaleStats', id, table=True)
            email['subscriberlocalestats'] = subscriberLocaleStats
            email['subscribercount'] = sum(s['total'] - s['send'] for s in subscriberLocaleStats)

            email['variationstats'] = postgres.call('EmailVariationStats', id, table=True)
        else:
            parts = parseURL(flask.request.url_root)
            email = {'draft': True, 'returnurlroot': parts['protocol'] + '//' + parts['root'] + '/'}

        email['exampleproperties'] = postgres.call('SubscriberExampleProperties')
        email['outgoingservers'] = postgres.select('OutgoingServer')
        email['incomingservers'] = postgres.select('IncomingServer')

    return flask.render_template('email.html', email=email, **kwargs)

@app.route('/email', methods=['POST'])
@app.route('/email/<int:id>', methods=['POST'])
def saveEmail(id=None):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if not id:
            id = postgres.insert('Email', form)['id']
            message = 'Email created.'
        else:
            if postgres.update('Email', form, {'id': id}):
                message = 'Email updated.'
            else:
                message = 'Email could not found.'

        return email(id, saveMessage=message)

@app.route('/email/<int:id>/variation', methods=['POST'])
@app.route('/email/<int:id>/variation/<int:rank>', methods=['POST'])
def saveEmailVariation(id, rank=None):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if not rank:
            form['emailid'] = id
            rank = postgres.insert('EmailVariation', form)['rank']
            message = 'Email variation created.'
        else:
            if postgres.update('EmailVariation', form, {'emailid': id, 'rank': rank, 'draft': True}):
                message = 'Email variation updated.'
            else:
                message = 'Email variation could not found.'

        return email(id, saveEmailVariationMessage=message, variationRank=rank)

@app.route('/email/<int:id>/variation/<int:rank>/remove', methods=['POST'])
def removeEmailVariation(id, rank):
    with postgres:
        if postgres.delete('EmailVariation', {'emailid': id, 'rank': rank, 'draft': True}):
            message = 'Email variation removed.'
        else:
            message = 'Email variation could not be removed.'

        return email(id, removeEmailVariationMessage=message, variationRank=rank)

@app.route('/email/<int:id>/variation/<int:rank>/sendTest', methods=['POST'])
def sendTestEmail(id, rank):
    with postgres:
        form = dict(flask.request.form.items())
        form['emailid'] = id
        form['variationrank'] = rank

        if postgres.call('SendTestEmail', form):
            message = 'Test email added to the queue.'
        else:
            message = 'Test email could not send. Subscriber may not be in the database.'

        return email(id, sendTestEmailMessage=message, variationRank=rank)

@app.route('/email/<int:id>/send', methods=['POST'])
def sendEmail(id):
    with postgres:
        form = {'emailid': id}
        for key, value in flask.request.form.items():
            if key[-2:] == '[]':
                form[key[:-2]] = [None if v == 'None' else v for v in flask.request.form.getlist(key)]
            else:
                form[key] = value

        subscriberCount = postgres.call('SendEmail', form)
        message = str(subscriberCount) + ' email added to the queue.'

        return email(id, sendEmailMessage=message)

@app.route('/email/<int:emailid>/preview/<int:rank>')
def preview(**kwargs):
    with postgres:
        emailVariation = postgres.select('EmailVariation', kwargs, table=False)

    if emailVariation and emailVariation['htmlbody']:
        return emailVariation['htmlbody']
    flask.abort(404)

@app.template_filter('validateURL')
def validateURL(input):
    try:
        from urllib.parse import quote # For Python 3
    except ImportError:
        from urllib import quote # For Python 2

    return 'http://validator.w3.org/check?uri=' + quote(input)


def parseURL(uRL):
    parts = {}
    parts['protocol'], address = uRL.split('//')
    parts['root'], parts['uRI'] = address.split('/', 1)
    if ':' in parts['root']:
        parts['root'], parts['port'] = parts['root'].split(':')
    return parts

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=True)

