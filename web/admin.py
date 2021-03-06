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
import collections

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart import postgres

app = flask.Flask(__name__)
app.config.update(**dict((k[6:], v) for k, v in os.environ.items() if k[:6] == 'FLASK_'))

##
# Routes
#
# Only POST and GET used on the routes because HTML forms does not accept other methods. Database transactions are
# used for data modification operations.
##

@app.route('/')
def index(**kwargs):
    kwargs['domains'] = postgres.connection().select('DomainDetail')
    kwargs['senders'] = postgres.connection().select('SenderStatistics')
    kwargs['bulkEmails'] = postgres.connection().select('EmailStatistics', {'bulk': True})

    return flask.render_template('index.html', **kwargs)

@app.route('/sender/new')
def newSender(**kwargs):
    parts = parseURL(flask.request.url_root)
    kwargs['sender'] = {
        'returnurlroot': parts['protocol'] + '//' + parts['root'] + '/',
        'password': postgres.connection().call('GeneratePassword'),
    }

    return flask.render_template('sender.html', **kwargs)

@app.route('/sender/<string:fromaddress>')
def editSender(**kwargs):
    identifiers = {key: kwargs.pop(key) for key in ('fromaddress',)}

    if 'sender' not in kwargs:
        kwargs['sender'] = postgres.connection().selectOne('Sender', identifiers)

    return flask.render_template('sender.html', **kwargs)

@app.route('/sender/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>', methods=['POST'])
def saveSender(**kwargs):
    with postgres.connection() as transaction:
        if 'fromaddress' not in kwargs:
            kwargs['sender'] = transaction.insert('Sender', formData())
            kwargs['fromaddress'] = kwargs['sender']['fromaddress']
            kwargs['senderMessage'] = 'Sender created.'
        else:
            kwargs['sender'] = transaction.updateOne('Sender', formData(), kwargs)
            kwargs['saveMessage'] = 'Sender updated.'

        return editSender(**kwargs)

@app.route('/sender/<string:fromaddress>/remove', methods=['POST'])
def removeSender(**kwargs):
    with postgres.connection() as transaction:
        transaction.deleteOne('Sender', kwargs)
        kwargs['senderMessage'] = 'Sender removed.'

        return index(**kwargs)

@app.route('/subscriber')
@app.route('/sender/<string:fromaddress>/subscriber')
def listSubscribers(**kwargs):
    return flask.render_template('subscribers.html', identifiers=kwargs,
                                 subscribers=postgres.connection().select('Subscriber', kwargs))

@app.route('/sender/<string:fromaddress>/subscriber/new')
def newSubscriber(**kwargs):
    return flask.render_template('subscriber.html', identifiers=kwargs, subscriber=kwargs, propertyCount=10)

@app.route('/sender/<string:fromaddress>/subscriber/new', methods=['POST'])
def saveSubscriber(**kwargs):
    with postgres.connection() as transaction:
        transaction.insert('Subscriber', formData(**kwargs))
        kwargs['saveMessage'] = 'Subscriber created.'

        return index(**kwargs)

@app.route('/email')
@app.route('/sender/<string:fromaddress>/email')
def listEmails(**kwargs):
    return flask.render_template('emails.html', identifiers=kwargs,
                                 emails=postgres.connection().select('EmailStatistics', kwargs))

@app.route('/sender/<string:fromaddress>/email/new')
def newEmail(**kwargs):
    identifiers = {key: kwargs.pop(key) for key in ('fromaddress',)}
    kwargs['email'] = {
        'fromaddress': identifiers['fromaddress'],
        'state': 'new',
    }
    kwargs['subscriberLocales'] = postgres.connection().select('SubscriberLocaleStatistics', identifiers)

    return flask.render_template('email.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>')
def editEmail(**kwargs):
    identifiers = {key: kwargs.pop(key) for key in ('fromaddress', 'emailid')}

    if 'email' not in kwargs:
        kwargs['email'] = postgres.connection().selectOne('Email', identifiers)

    kwargs['emailVariations'] = postgres.connection().select('EmailVariation', identifiers, 'variationId')
    kwargs['subscriberLocales'] = postgres.connection().select('SubscriberLocaleStatistics',
                                                               {'fromAddress': identifiers['fromaddress']})
    kwargs['exampleProperties'] = postgres.connection().call('SubscriberExampleProperties', identifiers['fromaddress'])
    kwargs['force'] = flask.request.args

    return flask.render_template('email.html', **kwargs)

@app.route('/sender/<string:fromaddress>/email/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>/email/<int:emailid>', methods=['POST'])
def saveEmail(**kwargs):
    with postgres.connection() as transaction:
        if 'emailid' not in kwargs:
            kwargs['email'] = transaction.insert('Email', formData(**kwargs))
            kwargs['emailid'] = kwargs['email']['emailid']
            kwargs['saveMessage'] = 'Email created.'
        else:
            kwargs['email'] = transaction.updateOne('Email', formData(), kwargs)
            kwargs['saveMessage'] = 'Email updated.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/remove', methods=['POST'])
def removeEmail(**kwargs):
    with postgres.connection() as transaction:
        transaction.deleteOne('Email', kwargs)
        kwargs['emailMessage'] = 'Email removed.'

        return index(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/new', methods=['POST'])
@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>', methods=['POST'])
def saveEmailVariation(**kwargs):
    with postgres.connection() as transaction:
        if 'variationid' not in kwargs:
            transaction.insert('EmailVariation', formData(**kwargs))
            kwargs['saveEmailVariationMessage'] = 'Email Variation created.'
        else:
            transaction.updateOne('EmailVariation', formData(), kwargs)
            kwargs['saveEmailVariationMessage'] = 'Email variation updated.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/remove', methods=['POST'])
def removeEmailVariation(**kwargs):
    with postgres.connection() as transaction:
        transaction.deleteOne('EmailVariation', kwargs)
        kwargs['removeEmailVariationMessage'] = 'Email Variation removed.'

        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/variation/<int:variationid>/sendTest', methods=['POST'])
def sendTestEmail(**kwargs):
    toAddress = formData()['toaddress']

    with postgres.connection() as transaction:
        transaction.insertIfNotExists('Subscriber', {
           'fromAddress': kwargs['fromaddress'],
           'toAddress': toAddress,
        })

        transaction.upsert('EmailSend', {
            'state': 'new',
            'variationId': kwargs['variationid'],
        }, {
            'fromAddress': kwargs['fromaddress'],
            'toAddress': toAddress,
            'emailId': kwargs['emailid'],
        })

        kwargs['sendTestEmailMessage'] = 'Test email message added to the queue.'
        return editEmail(**kwargs)

@app.route('/sender/<string:fromaddress>/email/<int:emailid>/sendBulk')
def prepareBulkEmail(**kwargs):
    identifiers = {key: kwargs.pop(key) for key in ('fromaddress', 'emailid')}

    kwargs['email'] = postgres.connection().selectOne('Email', identifiers)
    kwargs['subscriberLocales'] = postgres.connection().select('EmailSubscriberLocaleStatistics',
                                  dict(list(identifiers.items()) + [('locale', kwargs['email']['locale'])]))
    kwargs['emailVariations'] = postgres.connection().select('EmailVariationStatistics',
                                dict(list(identifiers.items()) + [('state', 'sent')]))
    kwargs['maxSubscriber'] = sum(row['remaining'] for row in kwargs['subscriberLocales'])
    kwargs['exampleProperties'] = postgres.connection().call('SubscriberExampleProperties', identifiers['fromaddress'])
    kwargs['propertyCount'] = 10
    kwargs['canSend'] = (kwargs['email']['bulk'] and kwargs['email']['state'] == 'sent' and
                         kwargs['maxSubscriber'] > 0 and kwargs['emailVariations'])

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
def emailStatistics(**kwargs):
    with postgres.connection() as transaction:
        context = {
            'identifiers': kwargs,
            'emailSentDates': transaction.select('EmailSentDateStatistics', kwargs),
            'emailVariations': transaction.select('EmailVariationStatistics', kwargs),
        }

        if 'emailid' in kwargs:
            context['email'] = transaction.selectOne('Email', kwargs)
            context['emailSubscriberLocales'] = transaction.select('EmailSubscriberLocaleStatistics', kwargs)
        else:
            context['emails'] = transaction.select('EmailStatistics', kwargs)

    return flask.render_template('emailstatistics.html', **context)

@app.route('/domain/statistics')
@app.route('/domain/<string:domain>/statistics')
def domainStatistics(**kwargs):
    context = {
        'identifiers': kwargs,
        'dMARCReports': postgres.connection().select('DMARCReportDetail', kwargs),
    }

    return flask.render_template('domainstatistics.html', **context)

@app.route('/reporter/<string:reporteraddress>/report/<string:reportid>')
def editReport(**kwargs):
    context = {
        'report': postgres.connection().selectOne('DMARCReport', kwargs),
        'dMARCReportRows': postgres.connection().select('DMARCReportRow', kwargs),
    }

    return flask.render_template('report.html', **context)

@app.route('/documentation')
def documentation(**kwargs):
    import api

    aPIMethods = []
    for rule in sorted(api.app.url_map.iter_rules(), key=lambda r: str(r)):
        for method in ('GET', 'POST', 'PUT', 'DELETE'):
            if method in rule.methods:
                aPIMethod = collections.OrderedDict()
                aPIMethod['name'] = method + ' ' + rule.rule
                aPIMethod['endpoint'] = rule.endpoint
                aPIMethod['methods'] = ', '.join(rule.methods)
                aPIMethods.append(aPIMethod)

    return flask.render_template('documentation.html', aPIMethods=aPIMethods)

##
# Helper functions
##

def uRLFor(*args, **kwargs):
    """Override the default url_for() view helper to remove unknown parameters on the URL."""
    return flask.helpers.url_for(*args, **kwargs).split('?')[0]
app.jinja_env.globals.update(url_for=uRLFor)

def formData(**kwargs):
    """Hydrate flask.request.form to a complex dictionary.  Elements like x[] will become an array in x.  Element
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
