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
import re
import email
import psycopg2

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres, PostgresNoRow
from libtart.email.server import IMAP4, IMAP4SSL
from libtart.email.message import Message
from libtart.helpers import warning

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sender', help='email address to receive email messages for')
    parser.add_argument('--amount', type=int, default=1, help='maximum email message amount to receive')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    parser.add_argument('--protocol', default='IMAP4', help='protocol to connect to the mail server, default IMAP4')
    IMAP4.addArguments(parser)

    arguments = vars(parser.parse_args())
    sender = arguments.pop('sender')
    amount = arguments.pop('amount')
    timeout = arguments.pop('timeout')
    debug = arguments.pop('debug')
    protocol = arguments.pop('protocol')
    # Remaining arguments are for IMAP4.

    if timeout:
        signal.alarm(timeout)

    if debug:
        Postgres.debug = True
        IMAP4.debug = True

    postgres = Postgres()

    if sender:
        with postgres:
            if not postgres.select('Sender', {'fromAddress': sender}):
                raise Exception('Sender does not exists.')

    server = globals()[protocol](**dict((k, v) for k, v in arguments.items() if v is not None))
    messageIds = server.execute('search', 'utf-8', 'UNSEEN')[0].split()
    print(str(len(messageIds)) + ' email messages to process.')

    for messageId in messageIds[:amount]:
        message = email.message_from_string(server.execute('fetch', messageId, '(RFC822)')[0][1], Message)
        message.check()
        returnedOriginal = None

        if message.get_content_type() in ('multipart/report', 'multipart/mixed'):
            # The last payload must be the returned original.
            returnedOriginal = message.get_payload()[-1]
        elif message.get_content_type() in ('text/plain', 'multipart/alternative'):
            warning('Unexpected plain text email message will be processed as returned original:', message)
            returnedOriginal = message
        else:
            warning('Unexpected MIME type:', message)

        if returnedOriginal:
            report = {}

            if returnedOriginal.is_multipart():
                report['originalHeaders'] = dict(returnedOriginal.get_payload(0).headers())
            else:
                splitMessage = returnedOriginal.splitSubmessage()
                if splitMessage:
                    report['body'], submessage = splitMessage
                    report['originalHeaders'] = dict(submessage.headers())
                else:
                    report['body'] = returnedOriginal.plainestWithoutQuote()

            if message.get_content_type() in ('multipart/report', 'multipart/mixed'):
                # Aditional fields for the standart response reports.
                if len(message.get_payload()) > 1:
                    report['body'] = message.get_payload(0).plainest()
                    if len(message.get_payload()) > 2:
                        report['fields'] = dict(message.get_payload()[-2].recursiveHeaders())

            if addResponseReport(sender, report):
                print(messageId + '. email message processed and will be deleted.')
                server.execute('store', messageId, '+FLAGS', '\Deleted')
            else:
                warning('Email could not found in the database:', message)

    if debug:
        print('Deleted emails will be left on the server in debug mode.')
    else:
        server.execute('expunge')

def addResponseReport(sender, report):
    emailSend = None

    if 'originalHeaders' in report and 'list-unsubscribe' in report['originalHeaders']:
        unsubscribeURL = report['originalHeaders']['list-unsubscribe'][1:-1]
        with postgres:
            emailSend = postgres.call('EmailSendFromUnsubscribeURL', ([sender] or []) + [unsubscribeURL])

    else:
        addresses = []

        if 'fields' in report:
            def addressInHeader(value):
                return value.split(';')[1] if ';' in value else value

            if 'original-recipient' in report['fields']:
                addresses.append(addressInHeader(report['fields']['original-recipient']).lower())

            if 'original-rcpt-to' in report['fields']:
                addresses.append(report['fields']['original-rcpt-to'].lower())

            if 'final-recipient' in report['fields']:
                addresses.append(addressInHeader(report['fields']['final-recipient']).lower())

        if 'originalHeaders' in report and 'to' in report['originalHeaders']:
            addresses.append(reports['originalHeaders']['to'].lower())

        if not addresses and 'body' in report:
            addresses = [e.lower() for e in re.findall('[A-Za-z0-9._\-+!'']+@[A-Za-z0-9.\-]+\.[A-Za-z0-9]+',
                                                       report['body'])]

        if addresses:
            with postgres:
                try:
                    emailSend = postgres.call('LastEmailSendToEmailAddresses', ([sender] or []) + [addresses])
                except PostgresNoRow: pass

    if emailSend:
        report['fromAddress'] = emailSend['fromaddress']
        report['toAddress'] = emailSend['toaddress']
        report['emailId'] = emailSend['emailid']

        with postgres:
            postgres.insert('EmailSendResponseReport', report)
            return True

    return False

if __name__ == '__main__':
    main()
