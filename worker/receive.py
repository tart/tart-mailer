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

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres, PostgresNoRow
from libtart.email.server import IMAP4, IMAP4SSL
from libtart.email.message import Message
from libtart.helpers import warning

postgres = Postgres()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sender', help='email address to receive email messages for')
    parser.add_argument('--amount', type=int, default=1, help='maximum email message amount to receive')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    parser.add_argument('--protocol', default='IMAP4', help='protocol to connect to the mail server, default IMAP4')
    parser.add_argument('--delete', action='store_true', help='delete processed messages from the mail server')
    IMAP4.addArguments(parser)

    arguments = vars(parser.parse_args())
    options = dict((k, arguments.pop(k)) for k in arguments.keys() if k in ('sender', 'amount', 'timeout', 'debug',
                                                                            'protocol', 'delete'))
    # Remaining arguments are for IMAP4.

    if options['timeout']:
        signal.alarm(options['timeout'])

    if options['debug']:
        Postgres.debug = True
        IMAP4.debug = True

    if options['sender']:
        with postgres:
            if not postgres.select('Sender', {'fromAddress': options['sender']}):
                raise Exception('Sender does not exists.')

    server = globals()[options['protocol']](**dict((k, v) for k, v in arguments.items() if v is not None))
    messageIds = server.execute('search', 'utf-8', 'UNSEEN')[0].split()
    print(str(len(messageIds)) + ' email messages to process.')

    for messageId in messageIds[:options['amount']]:
        message = email.message_from_string(server.execute('fetch', messageId, '(RFC822)')[0][1], Message)
        message.check()
        returnedOriginal = None

        ##
        # Messages will be classified by the last payload. It may be returned original or DMARC report.
        ##

        if message.lastPayload().get_content_type() in ('message/rfc822', 'text/rfc822-headers', 'text/plain',
                                                        'multipart/alternative'):

            if message.get_content_type() != 'multipart/report':
                warning('Unexpected message will be processed as returned original:', message)

            report = {}
            if returnedOriginal.is_multipart():
                report['body'] = message.get_payload(0).plainest()
                report['originalHeaders'] = dict(returnedOriginal.get_payload(0).headers())
            else:
                splitMessage = returnedOriginal.splitSubmessage()
                if splitMessage:
                    report['body'], submessage = splitMessage
                    report['originalHeaders'] = dict(submessage.headers())
                else:
                    report['body'] = returnedOriginal.plainestWithoutQuote()

            if message.get_content_type() == 'multipart/report' and len(message.get_payload()) > 2:
                # Aditional fields for the standart response reports.
                report['fields'] = dict(message.get_payload()[-2].recursiveHeaders())

            if addResponseReport(options['sender'], report):
                print(messageId + '. email message processed as returned original.')

                if options['delete']:
                    server.execute('store', messageId, '+FLAGS', '\Deleted')
            else:
                warning('Email messages cannot be saved to the database as response report:', message)

        elif message.lastPayload().get_content_type() in ('application/zip', 'application/x-zip-compressed'):
            from zipfile import ZipFile
            from cStringIO import StringIO

            with ZipFile(StringIO((message.lastPayload().get_payload(decode=True)))) as archive:
                if addDMARCReport(archive.read(archive.namelist()[0])):
                    print(messageId + '. email message processed as DMARC report.')

                    if options['delete']:
                        server.execute('store', messageId, '+FLAGS', '\Deleted')
                else:
                    warning('Email messages cannot be saved to the database as DMARC report:', message)

        else:
            warning('Unexpected MIME type:', message)

    if options['delete']:
        if options['debug']:
            print('Deleted emails will be left on the server in debug mode.')
        else:
            server.execute('expunge')

def addResponseReport(fromAddress, report):
    emailSend = None

    if 'originalHeaders' in report and 'list-unsubscribe' in report['originalHeaders']:
        unsubscribeURL = report['originalHeaders']['list-unsubscribe'][1:-1]
        with postgres:
            emailSend = postgres.call('EmailSendFromUnsubscribeURL', ([fromAddress] or []) + [unsubscribeURL])

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
                    emailSend = postgres.call('LastEmailSendToEmailAddresses', ([fromAddress] or []) + [addresses])
                except PostgresNoRow: pass

    if emailSend:
        report['fromAddress'] = emailSend['fromaddress']
        report['toAddress'] = emailSend['toaddress']
        report['emailId'] = emailSend['emailid']

        with postgres:
            postgres.insert('EmailSendResponseReport', report)
            return True

    return False

def addDMARCReport(body):
    import xml.etree.cElementTree as ElementTree
    from psycopg2.extras import DateTimeTZRange
    from datetime import datetime

    tree = ElementTree.fromstring(body)

    report = {
        'reporterAddress': tree.find('report_metadata/email').text,
        'reportId': tree.find('report_metadata/report_id').text,
        'domain': tree.find('policy_published/domain').text,
        'period': DateTimeTZRange(datetime.fromtimestamp(int(tree.find('report_metadata/date_range/begin').text)),
                                  datetime.fromtimestamp(int(tree.find('report_metadata/date_range/end').text))),
        'body': body
    }

    with postgres:
        postgres.insert('DMARCReport', report)

        for record in tree.iter('record'):
            postgres.insert('DMARCReportRow', {
                'reporterAddress': report['reporterAddress'],
                'reportId': report['reportId'],
                'source': record.find('row/source_ip').text,
                'messageCount': record.find('row/count').text,
                'disposition': record.find('row/policy_evaluated/disposition').text,
                'dKIMPass': record.find('row/policy_evaluated/dkim').text == 'pass',
                'sPFPass': record.find('row/policy_evaluated/spf').text == 'pass',
            })
            return True

    return False

if __name__ == '__main__':
    main()
