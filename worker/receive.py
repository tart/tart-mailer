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

from __future__ import absolute_import

import os
import signal
import imaplib
import psycopg2

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres
from libtart.email.server import parseArguments
from libtart.email.message import parseMessage
from libtart.helpers import warning

def main(server):
    postgres = Postgres()

    if 'project' in server:
        with postgres:
            if not postgres.select('Project', {'name': server['project']}):
                raise Exception('Project could not find in the database.')

    iMAP = imaplib.IMAP4(server['hostname'], server['port'])
    if server['username']:
        iMAP.login(server['username'], server['password'])
    print('IMAP connection successful.')

    status, response = iMAP.select(server['mailbox']) if server['mailbox'] else iMAP.select()
    if status != 'OK':
        raise Exception('IMAP mailbox problem: ' + status + ': ' + ' '.join(response))

    status, response = iMAP.search('utf-8', 'UNDELETED')
    if status != 'OK':
        raise Exception('IMAP search problem: ' + status + ': ' + ' '.join(response))

    messageIds = response[0].split()
    print(str(len(messageIds)) + ' emails to process.')

    for messageId in messageIds[:server['amount']]:
        status, response = iMAP.fetch(messageId, '(RFC822)')
        if status != 'OK':
            raise Exception('IMAP fetch problem: ' + status + ': ' + ' '.join(response))

        message = parseMessage(response[0][1])
        report = {}

        print(messageId + '. email will be processed as ' + message.get_content_type() + '.')

        if message.get_content_type() == 'multipart/report':
            report['body'] = message.get_payload(0).plainText()
            report['fields'] = dict(message.get_payload(1).recursiveHeaders())
            if len(message.get_payload()) > 2:
                report['originalHeaders'] = dict(message.get_payload(2).recursiveHeaders())
        elif message.get_content_type() in ('text/plain', 'multipart/alternative'):
            splitMessage = message.splitSubmessage()

            if splitMessage:
                report['body'], submessage = splitMessage
                report['originalHeaders'] = dict(submessage.headers())
                warning('Subemail will be processed as the returned original:', submessage)
            else:
                report['body'] = message.get_payload()
                warning('Unexpected plain text email will be processed:', report)
        else:
            warning('Unexpected MIME type:', message)

        if report:
            processed = False
            report['projectName'] = server['project']

            with postgres:
                try:
                    if postgres.call('NewEmailSendResponseReport', report):
                        print(messageId + '. email processed and will be deleted.')
                        processed = True
                    else:
                        warning('Email could not found in the database:', report)

                except psycopg2.IntegrityError as error:
                    warning(str(error), report)

                    if int(error.pgcode) == 23505:
                        # PostgreSQL UNIQUE VIOLATION error code.
                        print(messageId + '. email processed before and will be deleted.')
                        processed = True

            if processed:
                iMAP.store(messageId, '+FLAGS', '\DELETED')

if __name__ == '__main__':
    arguments = parseArguments(defaultProtocol='IMAP')

    if arguments.timeout:
        signal.alarm(arguments.timeout)

    main(vars(arguments))
