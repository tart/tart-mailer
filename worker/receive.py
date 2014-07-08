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

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
import libtart.postgres
import libtart.email.server
import libtart.email.message
import libtart.helpers

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sender', help='email address to receive email messages for')
    parser.add_argument('--amount', type=int, default=1, help='maximum email message amount to receive')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    parser.add_argument('--protocol', default='IMAP4', help='protocol to connect to the mail server, default IMAP4')
    parser.add_argument('--delete', action='store_true', help='delete processed messages from the mail server')
    libtart.email.server.IMAP4.addArguments(parser)

    arguments = vars(parser.parse_args())
    sender = arguments.pop('sender')
    amount = arguments.pop('amount')
    timeout = arguments.pop('timeout')
    debug = arguments.pop('debug')
    protocol = arguments.pop('protocol')
    delete = arguments.pop('delete')
    # Remaining arguments are about mail server.

    if timeout:
        signal.alarm(timeout)

    if debug:
        libtart.postgres.debug = True
        libtart.email.server.IMAP4.debug = True

    if sender:
        if not libtart.postgres.connection().select('Sender', {'fromAddress': sender}):
            raise Exception('Sender does not exists.')

    server = libtart.email.server.__dict__[protocol](**dict((k, v) for k, v in arguments.items() if v is not None))
    messageIds = server.execute('search', 'utf-8', 'UNSEEN')[0].split()
    print(str(len(messageIds)) + ' email messages to process.')

    for messageId in messageIds[:amount]:
        message = libtart.email.message.parse(server.execute('fetch', messageId, '(RFC822)')[0][1])
        message.check()

        ##
        # Messages will be classified by the last payload. It may be returned original or DMARC report.
        ##

        if message.lastPayload().get_content_type() in ('message/rfc822', 'text/rfc822-headers', 'text/plain',
                                                        'multipart/alternative'):

            if message.get_content_type() != 'multipart/report':
                libtart.helpers.warning('Unexpected message will be processed as returned original:', message)

            # In all the different cases, the returned original is always in the last payload.
            returnedOriginal = message.lastPayload()

            report = {}
            if returnedOriginal.is_multipart():
                report['body'] = message.get_payload(0).plainest()
                report['original'] = str(returnedOriginal.get_payload(0))
            else:
                splitMessage = returnedOriginal.splitSubmessage()
                if splitMessage:
                    report['body'], submessage = splitMessage
                    report['original'] = str(submessage)
                else:
                    report['body'] = returnedOriginal.plainestWithoutQuote()

            if message.get_content_type() == 'multipart/report' and len(message.get_payload()) > 2:
                # Aditional fields for the standart response reports.
                report['fields'] = dict(message.get_payload()[-2].recursiveHeaders())

            if addResponseReport(sender, report):
                print(str(int(messageId)) + '. email message processed as returned original.')

                if delete:
                    server.execute('store', messageId, '+FLAGS', '\Deleted')
            else:
                libtart.helpers.warning('Email messages cannot be saved to the database as response report:', message)

        elif message.lastPayload().get_content_type() in ('application/zip', 'application/x-zip-compressed'):
            from zipfile import ZipFile
            try:
               # cStringIO is gone on Python 3.
               from cStringIO import StringIO as IO
            except ImportError:
               from io import BytesIO as IO

            with ZipFile(IO((message.lastPayload().get_payload(decode=True)))) as archive:
                if addDMARCReport(archive.read(archive.namelist()[0])):
                    print(str(int(messageId)) + '. email message processed as DMARC report.')

                    if delete:
                        server.execute('store', messageId, '+FLAGS', '\Deleted')
                else:
                    libtart.helpers.warning('Email messages cannot be saved to the database as DMARC report:', message)

        else:
            libtart.helpers.warning('Unexpected MIME type:', message)

    if delete:
        if debug:
            print('Deleted emails will be left on the server in debug mode.')
        else:
            server.execute('expunge')

def addResponseReport(fromAddress, report):
    emailSend = None

    if 'originalHeaders' in report and 'list-unsubscribe' in report['originalHeaders']:
        unsubscribeURL = report['originalHeaders']['list-unsubscribe'][1:-1]
        emailSend = libtart.postgres.connection().call('EmailSendFromUnsubscribeURL', ([fromAddress] or []) + [unsubscribeURL])

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
            try:
                emailSend = libtart.postgres.connection().call('LastEmailSendToEmailAddresses', ([fromAddress] or []) +
                                                                                         [addresses])
            except libtart.postgres.NoRow: pass

    if emailSend:
        report['fromAddress'] = emailSend['fromaddress']
        report['toAddress'] = emailSend['toaddress']
        report['emailId'] = emailSend['emailid']

        libtart.postgres.connection().insert('EmailSendResponseReport', report)
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
        'body': body.decode('utf-8-sig')
    }

    with libtart.postgres.connection() as transaction:
        transaction.insert('DMARCReport', report)

        for record in tree.iter('record'):
            transaction.insert('DMARCReportRow', {
                'reporterAddress': report['reporterAddress'],
                'reportId': report['reportId'],
                'source': record.find('row/source_ip').text,
                'messageCount': record.find('row/count').text,
                'disposition': record.find('row/policy_evaluated/disposition').text,
                'dKIMPass': record.find('row/policy_evaluated/dkim').text == 'pass',
                'sPFPass': record.find('row/policy_evaluated/spf').text == 'pass',
            })

    return True

if __name__ == '__main__':
    main()
