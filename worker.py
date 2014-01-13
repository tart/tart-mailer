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
    parser.add_argument('--send', type=int, help='waiting email amount to send')

    return parser.parse_args()

arguments = parseArguments()
config = ConfigParser()
if not config.read(arguments.config):
    raise Exception('Configuration file cannot be read.')
postgres = Postgres(' '.join(k + '=' + v for k, v in config.items('postgres')))

def sendMail(count):
    assert count > 0

    with postgres:
        emailCount = postgres.callOneCell('EmailToSendCount')

    if emailCount > 0:
        if count > emailCount:
            count = emailCount

        print(str(count) + ' of ' + str(emailCount) + ' emails will be sent.')

        with smtplib.SMTP(config.get('smtp', 'host'), config.get('smtp', 'port')) as sMTP:
            if config.has_option('smtp', 'starttls') and config.getboolean('smtp', 'starttls'):
                sMTP.starttls()

            if config.has_option('smtp', 'user') and config.has_option('smtp', 'password'):
                sMTP.login(config.get('smtp', 'user'), config.get('smtp', 'password'))

            while count > 0:
                with postgres:
                    email = postgres.callOneLine('NextEmailToSend')

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

                count -= 1

if __name__ == '__main__':
    if arguments.send:
        sendMail(arguments.send)

