# -*- coding: utf-8 -*-
##
# Tart Library - Email Server Functions
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

import smtplib
import imaplib

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter

def addArgumentGroup(parser):
    '''Return ArgumentParser instance with the common arguments required to connect to an email server.'''

    group = parser.add_argument_group(description='Mail Server Arguments')
    group.add_argument('--host', help='hostname of the mail server')
    group.add_argument('--port', type=int, help='port for the mail server')
    group.add_argument('--username', help='username for the mail server')
    group.add_argument('--password', help='password for the incoming mail server')
    return group

class SMTP(smtplib.SMTP):
    '''Extend IMAP4 class on the standart library.'''

    @staticmethod
    def addArguments(parser):
        group = addArgumentGroup(parser)
        group.add_argument('--usetls', action='store_true', help='use TLS to connect to the mail server')

    def __init__(self, usetls=False, username=None, password=None, **kwargs):
        smtplib.SMTP.__init__(self, **kwargs)
        self.connect()

        if usetls:
            self.starttls()

        if username:
            self.login(username, password)

class IMAP4(imaplib.IMAP4):
    '''Extend IMAP4 class on the standart library.'''

    debug = False

    @staticmethod
    def addArguments(parser):
        group = addArgumentGroup(parser)
        group.add_argument('--mailbox', help='mailbox to receive emails, default INBOX')

    def __init__(self, username=None, password=None, mailbox=None, **kwargs):
        imaplib.IMAP4.__init__(self, **kwargs)

        if username:
            self.execute('login', username, password)

        if mailbox:
            self.execute('select', mailbox)
        else:
            self.execute('select')

    def execute(self, method, *args):
        status, response = getattr(self, method)(*args)

        if self.debug:
            print('IMAP4 ' + method + ' method returned ' + status + '.')
        if status != 'OK':
            raise IMAP4Exception('IMAP4 ' + method + ' method returned ' + status + ': ' + str(response))

        return response

class IMAP4SSL(imaplib.IMAP4_SSL, IMAP4):
    '''Extend IMAP4_SSL class on the standart library.'''

    def __init__(self, username=None, password=None, mailbox=None, **kwargs):
        imaplib.IMAP4_SSL.__init__(self, **kwargs)

        if username:
            self.execute('login', username, password)

        if mailbox:
            self.execute('select', mailbox)
        else:
            self.execute('select')

class IMAP4Exception(Exception):
    pass
