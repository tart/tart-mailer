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
import smtplib
import psycopg2

from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart.postgres import Postgres
from libtart.email.server import parseArguments
from libtart.helpers import warning

def main(server):
    postgres = Postgres()

    with postgres:
        if 'project' in server:
            if not postgres.select('Project', {'name': server['project']}):
                raise Exception('Project could not find in the database.')

        for emailSend in postgres.call('RemoveNotAllowedEmailSend', server['project'], table=True):
            warning('Not allowed email removed from the queue:', emailSend)

        count = postgres.call('EmailToSendCount', server['project'])

    print(str(count) + ' emails to send.')
    if count > server['amount']:
        count = server['amount']

    sMTP = smtplib.SMTP(server['hostname'], server['port'])
    if server['usetls']:
        sMTP.starttls()
    if server['username']:
        sMTP.login(server['username'], server['password'])
    print('SMTP connection successful.')

    for messageId in range(count):
        with postgres:
            email = postgres.call('NextEmailToSend', server['project'])

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
            message['To'] = email['toaddress']
            message['List-Unsubscribe'] = '<' + email['unsubscribeurl'] + '>'

            if email['bulk']:
                message['Precedence'] = 'bulk'

            sMTP.sendmail(email['fromaddress'], email['toaddress'], message.as_string())

        print(str(messageId) + '. email message sent to ' + email['toaddress'])

if __name__ == '__main__':
    arguments = parseArguments()

    if arguments.timeout:
        signal.alarm(arguments.timeout)

    main(vars(arguments))
