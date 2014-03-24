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

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))
postgres = Postgres()

@app.route('/')
def index(**kwargs):
    with postgres:
        return flask.render_template('index.html', senders=postgres.select('SenderDetail'),
                                     emails=postgres.select('EmailDetail'), **kwargs)

@app.route('/sender/new')
def newSender(**kwargs):
    with postgres:
        parts = parseURL(flask.request.url_root)
        root = parts['protocol'] + '//' + parts['root'] + '/'

        return flask.render_template('sender.html', returnurlroot=root, **kwargs)

@app.route('/sender/new', methods=['POST'])
def addSender():
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])
        postgres.insert('Sender', form)

        return index(senderMessage='Sender created.')

@app.route('/sender/<string:fromaddress>')
def sender(**kwargs):
    with postgres:
        parameters = {'fromaddress': kwargs['fromaddress']}

        kwargs.update(postgres.select('Sender', parameters, table=False))

        return flask.render_template('sender.html', **kwargs)

@app.route('/sender/<string:fromaddress>', methods=['POST'])
def saveSender(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if postgres.update('Sender', form, kwargs, table=False):
            kwargs['saveMessage'] = 'Sender updated.'
        else:
            kwargs['saveMessage'] = 'Sender could not found.'

        return sender(**kwargs)

@app.route('/sender/<string:fromaddress>/remove', methods=['POST'])
def removeSender(**kwargs):
    with postgres:
        if postgres.delete('Sender', kwargs):
            kwargs['senderMessage'] = 'Sender removed.'
        else:
            kwargs['senderMessage'] = 'Sender could not be removed.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/new')
def newEmail(**kwargs):
    return flask.render_template('email.html', draft=True, **kwargs)

@app.route('/sender/<string:fromaddress>/email/new', methods=['POST'])
def addEmail(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''] +
                    kwargs.items())

        postgres.insert('Email', form)
        kwargs['saveMessage'] = 'Email created.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>')
def email(**kwargs):
    with postgres:
        parameters = dict((k, v) for k, v in kwargs.items() if k in ('fromaddress', 'emailid'))

        kwargs.update(postgres.select('Email', parameters, table=False))

        kwargs['variations'] = postgres.select('EmailVariation', parameters)
        if flask.request.args.get('force'):
            kwargs['draft'] = True
            for variation in kwargs['variations']:
                variation['draft'] = True
        else:
            kwargs['draft'] = all(variation['draft'] for variation in kwargs['variations'])

        if kwargs['bulk']:
            subscriberLocaleStats = postgres.call('SubscriberLocaleStats', parameters, table=True)
            kwargs['subscriberlocalestats'] = subscriberLocaleStats
            kwargs['subscribercount'] = sum(s['total'] - s['send'] for s in subscriberLocaleStats)
            kwargs['variationstats'] = postgres.call('EmailVariationStats', parameters, table=True)

        kwargs['exampleproperties'] = postgres.call('SubscriberExampleProperties', kwargs['fromaddress'])

    return flask.render_template('email.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>', methods=['POST'])
def saveEmail(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if postgres.update('Email', form, kwargs):
            kwargs['saveMessage'] = 'Email updated.'
        else:
            kwargs['saveMessage'] = 'Email could not found.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/remove', methods=['POST'])
def removeEmail(**kwargs):
    with postgres:
        if postgres.delete('Email', **kwargs):
            kwargs['emailMessage'] = 'Email removed.'
        else:
            kwargs['emailMessage'] = 'Email could not be removed.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/new', methods=['POST'])
def addEmailVariation(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''] +
                    kwargs.items())

        postgres.insert('EmailVariation', form)
        kwargs['saveEmailVariationMessage'] = 'Email Variation created.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>', methods=['POST'])
def saveEmailVariation(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if postgres.update('EmailVariation', form, kwargs):
            kwargs['saveEmailVariationMessage'] = 'Email Variation updated.'
        else:
            kwargs['saveEmailVariationMessage'] = 'Email Variation could not found.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/remove', methods=['POST'])
def removeEmailVariation(**kwargs):
    with postgres:
        if postgres.delete('EmailVariation', **kwargs):
            kwargs['removeEmailVariationMessage'] = 'Email Variation removed.'
        else:
            kwargs['removeEmailVariationMessage'] = 'Email Variation could not be removed.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/sendTest', methods=['POST'])
def sendTestEmail(**kwargs):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''] +
                    kwargs.items())

        if postgres.call('SendTestEmail', form):
            kwargs['sendTestEmailMessage'] = 'Test email message added to the queue.'
        else:
            kwargs['sendTestEmailMessage'] = 'Test email message could not send. Subscriber may not be in the database.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/sendBulk', methods=['POST'])
def sendBulkEmail(**kwargs):
    with postgres:
        for key, value in flask.request.form.items():
            if key[-2:] == '[]':
                kwargs[key[:-2]] = [None if v == 'None' else v for v in flask.request.form.getlist(key)]
            else:
                kwargs[key] = value

        subscriberCount = postgres.call('SendBulkEmail', kwargs)
        kwargs['sendBulkEmailMessage'] = str(subscriberCount) + ' email messages added to the queue.'

        return email(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/preview')
def preview(**kwargs):
    with postgres:
        emailVariation = postgres.select('EmailVariation', kwargs, table=False)

    if emailVariation and emailVariation['htmlbody']:
        return emailVariation['htmlbody']
    flask.abort(404)

@app.route('/sender/<string:fromaddress>/statistics')
@app.route('/sender/<string:fromaddress>/email/<int:emailid>/statistics')
def emailStatistics(**kwargs):
    with postgres:
        return flask.render_template('emailstatistics.html',
                                     emailSentDates=postgres.select('EmailSentDateStatistics', kwargs),
                                     emailVariations=postgres.select('EmailVariationStatistics', kwargs),
                                     **kwargs)

def parseURL(uRL):
    parts = {}
    parts['protocol'], address = uRL.split('//')
    parts['root'], parts['uRI'] = address.split('/', 1)
    if ':' in parts['root']:
        parts['root'], parts['port'] = parts['root'].split(':')
    return parts

if __name__ == '__main__':
    Postgres.debug = True
    app.run(host='0.0.0.0', port=9000, debug=True)
