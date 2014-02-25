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
postgres = Postgres(debug=(__name__ == '__main__'))

@app.route('/')
def index(**kwargs):
    with postgres:
        return flask.render_template('index.html', projects=postgres.select('ProjectDetail'),
                                    emails=postgres.select('EmailDetail'), **kwargs)

@app.route('/project')
@app.route('/project/<string:name>')
def project(name=None, **kwargs):
    with postgres:
        if name:
            project = postgres.select('Project', {'name': name}, table=False)
        else:
            parts = parseURL(flask.request.url_root)
            project = {'returnurlroot': parts['protocol'] + '//' + parts['root'] + '/'}

    return flask.render_template('project.html', project=project, **kwargs)

@app.route('/project', methods=['POST'])
@app.route('/project/<string:name>', methods=['POST'])
def saveProject(name=None):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if not name:
            name = postgres.insert('Project', form)['name']
            message = 'Project "' + name + '" created.'
        else:
            newProject = postgres.update('Project', form, {'name': name}, table=False)
            if newProject:
                name = newProject['name']
                message = 'Project "' + name + '" updated.'
            else:
                message = 'Project "' + name + '" could not found.'

        return project(name, saveMessage=message)

@app.route('/project/<string:name>/remove', methods=['POST'])
def removeProject(name):
    with postgres:
        if postgres.delete('Project', {'name': name}):
            message = 'Project "' + name + '" removed.'
        else:
            message = 'Project "' + name + '" could not be removed.'

        return index(projectMessage=message)

@app.route('/email')
@app.route('/email/<int:id>')
def email(id=None, **kwargs):
    with postgres:
        if id:
            email = postgres.select('Email', {'id': id}, table=False)
            email['variations'] = postgres.select('EmailVariation', {'emailid': id})

            if flask.request.args.get('force'):
                email['draft'] = True
                for variation in email['variations']:
                    variation['draft'] = True
            else:
                email['draft'] = all(variation['draft'] for variation in email['variations'])

            if email['bulk']:
                subscriberLocaleStats = postgres.call('SubscriberLocaleStats', id, table=True)
                email['subscriberlocalestats'] = subscriberLocaleStats
                email['subscribercount'] = sum(s['total'] - s['send'] for s in subscriberLocaleStats)
                email['variationstats'] = postgres.call('EmailVariationStats', id, table=True)
        else:
            parts = parseURL(flask.request.url_root)
            email = {'draft': True, 'returnurlroot': parts['protocol'] + '//' + parts['root'] + '/'}

        email['exampleproperties'] = postgres.call('SubscriberExampleProperties')
        email['projects'] = postgres.select('Project')

    return flask.render_template('email.html', email=email, **kwargs)

@app.route('/email', methods=['POST'])
@app.route('/email/<int:id>', methods=['POST'])
def saveEmail(id=None):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])
        print(flask.request.form.items())

        if not id:
            id = postgres.insert('Email', form)['id']
            message = str(id) + '. Email created.'
        else:
            if postgres.update('Email', form, {'id': id}):
                message = str(id) + '. Email updated.'
            else:
                message = str(id) + '. Email could not found.'

        return email(id, saveMessage=message)

@app.route('/email/<int:id>/remove', methods=['POST'])
def removeEmail(id):
    with postgres:
        if postgres.delete('Email', {'id': id}):
            message = str(id) + '. Email removed.'
        else:
            message = str(id) + '. Email could not be removed.'

        return index(emailMessage=message)

@app.route('/email/<int:id>/variation', methods=['POST'])
@app.route('/email/<int:id>/variation/<int:rank>', methods=['POST'])
def saveEmailVariation(id, rank=None):
    with postgres:
        form = dict([(k, v) for k, v in flask.request.form.items() if v != ''])

        if not rank:
            form['emailid'] = id
            rank = postgres.insert('EmailVariation', form)['rank']
            message = str(rank) + '. Email Variation created.'
        else:
            if postgres.update('EmailVariation', form, {'emailid': id, 'rank': rank}):
                message = str(rank) + '. Email Variation updated.'
            else:
                message = str(rank) + '. Email Variation could not found.'

        return email(id, saveEmailVariationMessage=message, variationRank=rank)

@app.route('/email/<int:id>/variation/<int:rank>/remove', methods=['POST'])
def removeEmailVariation(id, rank):
    with postgres:
        if postgres.delete('EmailVariation', {'emailid': id, 'rank': rank}):
            message = str(rank) + '. Email Variation removed.'
        else:
            message = str(rank) + '. Email Variation could not be removed.'

        return email(id, removeEmailVariationMessage=message, variationRank=rank)

@app.route('/email/<int:id>/variation/<int:rank>/sendTest', methods=['POST'])
def sendTestEmail(id, rank):
    with postgres:
        form = dict(flask.request.form.items())
        form['emailid'] = id
        form['variationrank'] = rank

        if postgres.call('SendTestEmail', form):
            message = 'Test email message added to the queue.'
        else:
            message = 'Test email message could not send. Subscriber may not be in the database.'

        return email(id, sendTestEmailMessage=message, variationRank=rank)

@app.route('/email/<int:id>/sendBulk', methods=['POST'])
def sendBulkEmail(id):
    with postgres:
        form = {'emailid': id}
        for key, value in flask.request.form.items():
            if key[-2:] == '[]':
                form[key[:-2]] = [None if v == 'None' else v for v in flask.request.form.getlist(key)]
            else:
                form[key] = value

        subscriberCount = postgres.call('SendBulkEmail', form)
        message = str(subscriberCount) + ' email messages added to the queue.'

        return email(id, sendBulkEmailMessage=message)

@app.route('/email/<int:emailid>/preview/<int:rank>')
def preview(**kwargs):
    with postgres:
        emailVariation = postgres.select('EmailVariation', kwargs, table=False)

    if emailVariation and emailVariation['htmlbody']:
        return emailVariation['htmlbody']
    flask.abort(404)

@app.route('/email/variations')
@app.route('/email/<int:id>/variations')
def emailVariations(id=None):
    with postgres:
        if id:
            return flask.render_template('emailvariations.html', email={'id': id},
                                         emailVariations=postgres.select('EmailVariationDetail', {'emailid': id}))
        return flask.render_template('emailvariations.html', emailVariations=postgres.select('EmailVariationDetail'))

def parseURL(uRL):
    parts = {}
    parts['protocol'], address = uRL.split('//')
    parts['root'], parts['uRI'] = address.split('/', 1)
    if ':' in parts['root']:
        parts['root'], parts['port'] = parts['root'].split(':')
    return parts

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9000, debug=True)
