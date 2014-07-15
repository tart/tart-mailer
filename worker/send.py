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
import psycopg2

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart import postgres
from libtart.email.server import SMTP
from libtart.helpers import warning

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sender', help='email address to send email messages')
    parser.add_argument('--amount', type=int, default=1, help='maximum email message amount to send')
    parser.add_argument('--offset', type=int, default=0, help='message amount to skip for concurrency')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--debug', action='store_true', help='debug mode')
    SMTP.addArguments(parser)

    arguments = vars(parser.parse_args())
    sender = arguments.pop('sender')
    amount = arguments.pop('amount')
    offset = arguments.pop('offset')
    timeout = arguments.pop('timeout')
    debug = arguments.pop('debug')
    # Remaining arguments are about mail server.

    if timeout:
        signal.alarm(timeout)

    if debug:
        postgres.debug = True

    if sender:
        if not postgres.connection().select('Sender', {'fromAddress': sender}):
            raise Exception('Sender does not exists.')

    for emailSend in postgres.connection().callTable('CancelNotAllowedEmailSend', sender):
        warning('Not allowed email messages removed from the queue:', emailSend)

    count = postgres.connection().call('EmailToSendCount', sender)
    print(str(count) + ' waiting email messages to send.')

    sMTP = SMTP(**arguments)
    print('SMTP connection successful.')

    amount = min(amount, count)
    offset = min(offset, count - amount)

    for i in range(amount):
        with postgres.connection() as transaction:
            try:
                email = transaction.call('NextEmailToSend', (sender, offset))
            except postgres.NoRow:
                print('No messages left to send. Probably another worker had sent them.')
                break

            if email['plainbody'] and email['htmlbody']:
                message = MIMEMultipart('alternative')
                message.attach(MIMEText(email['plainbody'], 'plain', 'utf-8'))
                message.attach(MIMEText(email['htmlbody'], 'html', 'utf-8'))
                # According to RFC 2046, the last part of a multipart message, in this case the HTML message,
                # is best and should be preferred. See the note for implementors on RFC 2046 page 25.
            elif email['htmlbody']:
                message = MIMEText(email['htmlbody'], 'html', 'utf-8')
            else:
                message = MIMEText(email['plainbody'], 'plain', 'utf-8')

            message['Subject'] = email['subject']
            message['From'] = formataddr((email['fromname'], email['fromaddress']))

            if email['returnpath']:
                message['Return-Path'] = '<' + email['returnpath'] + '>'

            if email['replyto']:
                message['Reply-To'] = '<' + email['replyto'] + '>'

            message['To'] = email['toaddress']
            message['List-Unsubscribe'] = '<' + email['unsubscribeurl'] + '>'

            if email['bulk']:
                message['Precedence'] = 'bulk'

            sMTP.sendmail(email['fromaddress'], email['toaddress'], message.as_string())

        print(str(email['sendorder']) + '. email message sent to ' + email['toaddress'])

if __name__ == '__main__':
    main()
