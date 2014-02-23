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

from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter

# Default ports for currently supported protocols.
defaultPorts = {'SMTP': 25, 'IMAP': 143}

def parseArguments(defaultProtocol='SMTP'):
    '''Create ArgumentParser instance. Return parsed arguments.'''

    parser = ArgumentParser(formatter_class=ArgumentDefaultsHelpFormatter, description=__doc__)
    parser.add_argument('--project', help='project name to send or receive emails')
    parser.add_argument('--amount', type=int, default=1, help='maximum email amount')
    parser.add_argument('--timeout', type=int, help='seconds to kill the process')
    parser.add_argument('--protocol', default=defaultProtocol, help='protocol of the mail server')
    parser.add_argument('--hostname', default='localhost', help='hostname of the mail server')
    parser.add_argument('--port', type=int, default=defaultPorts[defaultProtocol], help='port for the mail server')
    parser.add_argument('--username', help='username for the mail server')
    parser.add_argument('--password', help='password for the incoming mail server')
    parser.add_argument('--usetls', action='store_true', help='use TLS to connect to the mail server')
    parser.add_argument('--mailbox', default='INBOX', help='mailbox to receive emails')

    return parser.parse_args()
