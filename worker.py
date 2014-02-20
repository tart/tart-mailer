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

from __future__ import print_function

import sys
import email
import smtplib
import imaplib
import signal
import psycopg2

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr
from libtart.postgres import Postgres

def parseArguments():
    '''Create ArgumentParser instance. Return parsed arguments.'''

    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter, description=__doc__)
    parser.add_argument('--send', type=int, help='waiting email amount to send')
    parser.add_argument('--outgoing-server', help='outgoing server to send emails')
    parser.add_argument('--receive', type=int, help='waiting email amount to send')
    parser.add_argument('--incoming-server', help='incoming server to receive emails')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')

    return parser.parse_args()

def sendEmail(serverName, amount):
    postgres = Postgres()

    with postgres:
        server = postgres.call('OutgoingServerToSend', serverName)
        if not server:
            raise Exception('Outgoing server could not find in the database.')

        for emailSend in postgres.call('RemoveNotAllowedEmailSend', serverName, table=True):
            warning('Not allowed email removed from the queue:' **emailSend)

    if amount > server['totalcount']:
        amount = server['totalcount']
    print(str(server['totalcount']) + ' emails to send.')

    sMTP = smtplib.SMTP(server['hostname'], server['port'])
    if server['usetls']:
        sMTP.starttls()
    if server['username']:
        sMTP.login(server['username'], server['password'])
    print('SMTP connection successful.')

    while amount > 0:
        with postgres:
            email = postgres.call('NextEmailToSend', serverName)

            if email['plainbody'] and email['htmlbody']:
                message = MIMEMultipart('alternative')
                message.attach(MIMEText(email['plainbody'], 'plain', 'utf-8'))
                message.attach(MIMEText(email['htmlbody'], 'html', 'utf-8'))
            elif email['htmlbody']:
                message = MIMEText(email['htmlbody'], 'html', 'utf-8')
            else:
                message = MIMEText(email['plainbody'], 'plain', 'utf-8')

            message['Subject'] = email['subject']
            message['From'] = formataddr((email['fromname'], email['fromaddress']))
            message['To'] = email['toaddress']
            message['List-Unsubscribe'] = '<' + email['unsubscribeurl'] + '>'

            if email['bulk']:
                message['Precedence'] = 'bulk'

            sMTP.sendmail(email['fromaddress'], email['toaddress'], message.as_string())

        amount -= 1

def receiveEmail(serverName, amount):
    postgres = Postgres()

    with postgres:
        server = postgres.select('IncomingServer', {'name': serverName}, table=False)
        if not server:
            raise Exception('Incoming server could not find in the database.')

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

    emailIds = response[0].split()
    print(str(len(emailIds)) + ' emails to process.')

    while amount > 0 and emailIds:
        emailId = emailIds.pop(0)
        status, response = iMAP.fetch(emailId, '(RFC822)')
        if status != 'OK':
            raise Exception('IMAP fetch problem: ' + status + ': ' + ' '.join(response))

        message = email.message_from_string(response[0][1])

        # Sanity checks, see http://tools.ietf.org/html/rfc3464#page-7
        if (message.get_content_type() == 'multipart/report'
                and message.is_multipart()
                and len(message.get_payload()) >= 2
                and message.get_payload(1).get_content_type() == 'message/delivery-status'):

            fields = recursiveEmailHeaders(message.get_payload(1))
            originalHeaders = recursiveEmailHeaders(message.get_payload(2)) if len(message.get_payload()) > 2 else []

            with postgres:
                try:
                    if postgres.call('NewEmailSendResponseReport', [serverName, dict(fields), dict(originalHeaders)]):
                        iMAP.store(emailId, '+FLAGS', '\DELETED')
                    else:
                        warning('Email could not found in the database:', **dict(fields))
                except psycopg2.IntegrityError as error:
                    warning(str(error), **message)
        else:
            warning('Unexpected email:', **message)

        amount -= 1

def recursiveEmailHeaders(message):
    return (item for part in message.walk() for item in part.items())

def warning(message, **kwargs):
    print('WARNING: ' + str(message), file=sys.stderr)

    for key, value in kwargs.items():
        print('\t' + key + ': ' + value, file=sys.stderr)

    print(file=sys.stderr)

if __name__ == '__main__':
    arguments = parseArguments()

    if arguments.timeout:
        signal.alarm(arguments.timeout)

    if arguments.send:
        if not arguments.outgoing_server:
            raise Exception('--outgoing-server is requred for sending emails.')
        sendEmail(arguments.outgoing_server, arguments.send)

    if arguments.receive:
        if not arguments.incoming_server:
            raise Exception('--incoming-server is requred for sending emails.')
        receiveEmail(arguments.incoming_server, arguments.receive)
