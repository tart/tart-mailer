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

import smtplib

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from configparser import ConfigParser
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formataddr
from libtart.postgres import Postgres

def parseArguments():
    '''Create ArgumentParser instance. Return parsed arguments.'''

    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter, description=__doc__)
    parser.add_argument('--config', default='./mailer.conf', help='configuration file path')
    parser.add_argument('--server', default='localhost', help='outgoing server to send emails')
    parser.add_argument('--amount', type=int, default=1, help='waiting email amount to send')

    return parser.parse_args()

arguments = parseArguments()
config = ConfigParser()
if not config.read(arguments.config):
    raise Exception('Configuration file cannot be read.')
postgres = Postgres(' '.join(k + '=' + v for k, v in config.items('postgres')))

def sendMail(serverName, amount):
    assert amount> 0

    with postgres:
        server = postgres.callOneLine('OutgoingServerToSend', serverName)

    if server:
        if amount > server['totalcount']:
            amount = server['totalcount']
        print(str(amount) + ' of ' + str(server['totalcount']) + ' emails will be sent.')

        sMTP = smtplib.SMTP(server['hostname'], server['port'])
        if server['usetls']:
            sMTP.starttls()
        if server['username']:
            sMTP.login(server['username'], server['password'])
        print('SMTP connection successful.')

        while amount > 0:
            with postgres:
                email = postgres.callOneLine('NextEmailToSend', serverName)

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

                sMTP.sendmail(email['fromaddress'], email['toaddress'], message.as_string())

            amount -= 1

if __name__ == '__main__':
    sendMail(arguments.server, arguments.amount)

