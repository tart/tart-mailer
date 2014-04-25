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
import jinja2

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart import postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))

##
# Routes
#
# Only POST and GET used on the routes because HTML forms does not accept other methods. Database transactions
# used for data modification operations.
##

@app.route('/')
def index(**kwargs):
    kwargs['domains'] = postgres.connection().select('DomainDetail')
    kwargs['senders'] = postgres.connection().select('SenderDetail')
    kwargs['bulkEmails'] = postgres.connection().select('BulkEmailDetail')

    return flask.render_template('index.html', **kwargs)

@app.route('/sender/new')
def newSender(**kwargs):
    parts = parseURL(flask.request.url_root)
    kwargs['returnurlroot'] = parts['protocol'] + '//' + parts['root'] + '/'
    kwargs['password'] = postgres.connection().call('GeneratePassword')

    return flask.render_template('sender.html', **kwargs)

@app.route('/sender/<string:fromaddress>')
def editSender(**kwargs):
    parameters = {'fromaddress': kwargs['fromaddress']}

    kwargs.update(postgres.connection().selectOne('Sender', parameters))

    return flask.render_template('sender.html', **kwargs)

@app.route('/sender/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>', methods=['POST'])
def saveSender(**kwargs):
    with postgres.connection() as transaction:
        if 'fromaddress' not in kwargs:
            kwargs = transaction.insert('Sender', formData())
            kwargs['senderMessage'] = 'Sender created.'
        else:
            if transaction.updateOne('Sender', formData(), kwargs):
                kwargs['saveMessage'] = 'Sender updated.'
            else:
                kwargs['saveMessage'] = 'Sender could not found.'

        return editSender(**kwargs)

@app.route('/sender/<string:fromaddress>/remove', methods=['POST'])
def removeSender(**kwargs):
    with postgres.connection() as transaction:
        if transaction.delete('Sender', kwargs):
            kwargs['senderMessage'] = 'Sender removed.'
        else:
            kwargs['senderMessage'] = 'Sender could not be removed.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/subscriber/new')
def newSubscriber(**kwargs):
    kwargs['propertyCount'] = 10

    return flask.render_template('subscriber.html', **kwargs)

@app.route('/sender/<string:fromaddress>/subscriber/new', methods=['POST'])
def saveSubscriber(**kwargs):
    with postgres.connection() as transaction:
        transaction.insert('Subscriber', formData(**kwargs))
        kwargs['saveMessage'] = 'Subscriber created.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/new')
def newEmail(**kwargs):
    kwargs['draft'] = True

    return flask.render_template('email.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>')
def editEmail(**kwargs):
    parameters = dict((k, v) for k, v in kwargs.items() if k in ('fromaddress', 'emailid'))

    kwargs.update(postgres.connection().selectOne('Email', parameters))

    kwargs['variations'] = postgres.connection().select('EmailVariation', parameters)
    if 'force' in flask.request.args:
        kwargs['draft'] = True
        for variation in kwargs['variations']:
            variation['draft'] = True
    else:
        kwargs['draft'] = all(variation['draft'] for variation in kwargs['variations'])

    kwargs['exampleproperties'] = postgres.connection().call('SubscriberExampleProperties', kwargs['fromaddress'])

    return flask.render_template('email.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>/email/<int:emailid>', methods=['POST'])
def saveEmail(**kwargs):
    with postgres.connection() as transaction:
        if 'emailid' not in kwargs:
            kwargs.update(transaction.insert('Email', formData(**kwargs)))
            kwargs['saveMessage'] = 'Email created.'
        else:
            if transaction.update('Email', formData(), kwargs):
                kwargs['saveMessage'] = 'Email updated.'
            else:
                kwargs['saveMessage'] = 'Email could not found.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/remove', methods=['POST'])
def removeEmail(**kwargs):
    with postgres.connection() as transaction:
        if transaction.delete('Email', kwargs):
            kwargs['emailMessage'] = 'Email removed.'
        else:
            kwargs['emailMessage'] = 'Email could not be removed.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>', methods=['POST'])
def saveEmailVariation(**kwargs):
    with postgres.connection() as transaction:
        if 'variationid' not in kwargs:
            transaction.insert('EmailVariation', formData(**kwargs))
            kwargs['saveEmailVariationMessage'] = 'Email Variation created.'
        else:
            if transaction.update('EmailVariation', formData(), kwargs):
                kwargs['saveEmailVariationMessage'] = 'Email Variation updated.'
            else:
                kwargs['saveEmailVariationMessage'] = 'Email Variation could not found.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/remove', methods=['POST'])
def removeEmailVariation(**kwargs):
    with postgres.connection() as transaction:
        if transaction.delete('EmailVariation', kwargs):
            kwargs['removeEmailVariationMessage'] = 'Email Variation removed.'
        else:
            kwargs['removeEmailVariationMessage'] = 'Email Variation could not be removed.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/sendTest', methods=['POST'])
def sendTestEmail(**kwargs):
    with postgres.connection() as transaction:
        if transaction.call('SendTestEmail', formData(**kwargs)):
            kwargs['sendTestEmailMessage'] = 'Test email message added to the queue.'
        else:
            kwargs['sendTestEmailMessage'] = 'Test email message could not send.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/sendBulk')
def prepareBulkEmail(**kwargs):
    parameters = dict((k, v) for k, v in kwargs.items() if k in ('fromaddress', 'emailid'))
    subscriberLocaleStats = postgres.connection().callTable('SubscriberLocaleStats', parameters)
    kwargs['subscriberlocalestats'] = subscriberLocaleStats
    kwargs['subscribercount'] = sum(s['total'] - s['send'] for s in subscriberLocaleStats)
    kwargs['emailVariations'] = postgres.connection().select('EmailVariationStatistics', parameters)
    kwargs['exampleproperties'] = postgres.connection().call('SubscriberExampleProperties', kwargs['fromaddress'])
    kwargs['propertyCount'] = 10

    return flask.render_template('bulkemail.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/sendBulk', methods=['POST'])
def sendBulkEmail(**kwargs):
    with postgres.connection() as transaction:
        subscriberCount = transaction.call('SendBulkEmail', formData(**kwargs))
        kwargs['message'] = str(subscriberCount) + ' email messages added to the queue.'

        return prepareBulkEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/preview')
def preview(**kwargs):
    emailVariation = postgres.connection().selectOne('EmailVariation', kwargs)

    if emailVariation and emailVariation['htmlbody']:
        return emailVariation['htmlbody']
    flask.abort(404)

@app.route('/sender/statistics')
@app.route('/sender/<string:fromaddress>/statistics')
@app.route('/sender/<string:fromaddress>/email/<int:emailid>/statistics')
def senderStatistics(**kwargs):
    return flask.render_template('senderstatistics.html',
                                 emailSentDates=postgres.connection().select('EmailSentDateStatistics', kwargs),
                                 emailVariations=postgres.connection().select('EmailVariationStatistics', kwargs),
                                 **kwargs)

@app.route('/domain/statistics')
@app.route('/domain/<string:domain>/statistics')
def domainStatistics(**kwargs):
    return flask.render_template('domainstatistics.html',
                                 dMARCReports=postgres.connection().select('DMARCReportDetail', kwargs),
                                 **kwargs)

@app.route('/reporter/<string:reporteraddress>/report/<string:reportid>')
def report(**kwargs):
    parameters = dict(kwargs)
    kwargs.update(postgres.connection().selectOne('DMARCReport', parameters))
    kwargs['rows'] = postgres.connection().select('DMARCReportRow', parameters)

    return flask.render_template('report.html', **kwargs)

##
# Helper functions
##

@jinja2.contextfunction
def uRLFor(context, *args, **kwargs):
    """Override the default url_for() view helper with a magical one. The magic is to use the context variables
    as the default kwargs. It will also change the default behavior not to add unknown parameters to the URL
    with an ugly split() hack."""

    values = dict(context)
    values.update(kwargs)

    return flask.helpers.url_for(*args, **values).split('?')[0]
app.jinja_env.globals.update(url_for=uRLFor)

def formData(**kwargs):
    """Hydrate flask.request.form to a complex dictionary. Elements like x[] will become a an array in x. Element
    pairs like y[3][key] and y[3][value] will become a dictionary in y."""

    for key, value in flask.request.form.items():
        if key[-1] == ']':
            if key[-5:] == '[key]':
                element = key[:key.index('[')]
                if element not in kwargs:
                    kwargs[element] = {}
                if value != '':
                    kwargs[element][value] = flask.request.form[key[:-5] + '[value]']

            elif key[-2] == '[':
                kwargs[key[:-2]] = [None if v == 'None' else v for v in flask.request.form.getlist(key)]

        elif value != '':
            kwargs[key] = value

    return kwargs

def parseURL(uRL):
    parts = {}
    parts['protocol'], address = uRL.split('//')
    parts['root'], parts['uRI'] = address.split('/', 1)
    if ':' in parts['root']:
        parts['root'], parts['port'] = parts['root'].split(':')
    return parts

##
# HTTP server for development
#
# Do not use it on production.
##
if __name__ == '__main__':
    postgres.debug = True
    app.run(port=9000, debug=True)
