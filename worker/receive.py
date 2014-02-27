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
import argparse
import email
import psycopg2

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres
from libtart.email.server import IMAP4
from libtart.email.message import Message
from libtart.helpers import warning

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', help='project name to receive email messages for')
    parser.add_argument('--amount', type=int, default=1, help='maximum email message amount to receive')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    IMAP4.addArguments(parser)

    arguments = vars(parser.parse_args())
    project = arguments.pop('project')
    amount = arguments.pop('amount')
    timeout = arguments.pop('timeout')
    debug = arguments.pop('debug')

    if timeout:
        signal.alarm(timeout)

    if debug:
        Postgres.debug = True
        IMAP4.debug = True

    postgres = Postgres()

    if project:
        with postgres:
            if not postgres.select('Project', {'name': project}):
                raise Exception('Project could not find in the database.')

    server = IMAP4(**arguments)
    messageIds = server.execute('search', 'utf-8', 'UNDELETED')[0].split()
    print(str(len(messageIds)) + ' email messages to process.')

    for messageId in messageIds[:amount]:
        message = email.message_from_string(server.execute('fetch', messageId, '(RFC822)')[0][1], Message)
        report = {}

        if message.get_content_type() in ('multipart/report', 'multipart/mixed'):
            if len(message.get_payload()) == 1:
                report['originalHeaders'] = dict(message.get_payload(0).get_payload(0).headers())
            else:
                report['body'] = message.get_payload(0).plainText()
                if len(message.get_payload()) == 2:
                    report['originalHeaders'] = dict(message.get_payload(1).get_payload(0).headers())
                else:
                    report['fields'] = dict(message.get_payload(1).get_payload(0).headers())
                    report['originalHeaders'] = dict(message.get_payload(2).get_payload(0).headers())

        elif message.get_content_type() in ('text/plain', 'multipart/alternative'):
            splitMessage = message.splitSubmessage()
            if splitMessage:
                report['body'], submessage = splitMessage
                report['originalHeaders'] = dict(submessage.headers())
                warning('Sub-message will be processed as the returned original:', submessage)
            else:
                report['body'] = message.plainTextWithoutQuote()
                warning('Unexpected plain text email message will be processed:', report)

        else:
            warning('Unexpected MIME type:', message)

        if report:
            report['projectName'] = project

            with postgres:
                try:
                    if postgres.call('NewEmailSendResponseReport', report):
                        print(messageId + '. email message processed and will be deleted.')
                        server.execute('store', messageId, '+FLAGS', '\Deleted')
                    else:
                        warning('Email could not found in the database:', report)

                except psycopg2.IntegrityError as error:
                    warning(str(error), report)

                    if int(error.pgcode) == 23505:
                        # PostgreSQL UNIQUE VIOLATION error code.
                        print(messageId + '. email message processed before and will be deleted.')
                        server.execute('store', messageId, '+FLAGS', '\Deleted')

        server.execute('expunge')

if __name__ == '__main__':
    main()
