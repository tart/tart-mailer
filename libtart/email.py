# -*- coding: utf-8 -*-
##
# Tart Library - Email Classes
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

import email

def parseMessage(string):
    message = email.message_from_string(string, EmailMessage)

    # Messages without subject does not considered valid.
    if 'Subject' not in message:
        return None

    # Sanity checks for response reports, see http://tools.ietf.org/html/rfc3464#page-7
    if message.get_content_type() == 'multipart/report':
        assert (message.is_multipart()
                and len(message.get_payload()) >= 2
                and message.get_payload(1).get_content_type() == 'message/delivery-status')

    # Sanity checks plain text emails
    if message.get_content_type() == 'text/plain':
        assert not message.is_multipart()

    # New line does not allowed on the subject.
    if '\n' in message['Subject']:
        message.replace_header('Subject', ' '.join(line.strip() for line in message['subject'].split('\n')))

    return message

class EmailMessage(email.message.Message):
    '''Extend the email.message.Message class on the standart library.'''

    def submessageInsidePayload(self):
        '''Search for messages inside the message payload.'''

        splitPayload = self.get_payload().split('\n')

        for num, line in enumerate(splitPayload):
            if not line.strip():
                message = parseMessage('\n'.join(splitPayload[(num + 1):]))
                if message:
                    return message

    def recursiveItems(self):
        '''Walk inside the message, merge found headers. Useful for multipart messages. Be careful that it can
        include the same header more than once.'''

        return (item for part in self.walk() for item in part.items())
