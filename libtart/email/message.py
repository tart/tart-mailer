# -*- coding: utf-8 -*-
##
# Tart Library - Email Message Functions
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

import email

from email.message import Message

def parseMessage(string):
    message = email.message_from_string(string, EmailMessage)

    # Messages without subject does not considered valid.
    if 'subject' not in message:
        return None

    if message.get_content_type() == 'multipart/report':
        # Sanity checks for response reports, according to RFC 2464 page 7.
        assert message.is_multipart()
        assert len(message.get_payload()) >= 2
        assert message.get_payload(1).get_content_type() in ('message/delivery-status',
                                                             'message/feedback-report',
                                                             'text/plain')

    if message.get_content_type() == 'text/plain':
        # Sanity checks plain text emails.
        assert not message.is_multipart()

    return message

class EmailMessage(Message):
    '''Extend the Message class on the standart library.'''

    def plainText(self):
        '''Return the text/plain payload or first payload inside multipart/alternative message which should
        be the plainest according to RFC 2046 page 24.'''

        if self.get_content_type() == 'text/plain':
            return self.get_payload()
        if self.get_content_type() == 'multipart/alternative':
            return self.get_payload(0).get_payload()

    def headers(self):
        '''Return headers with lower case names and without new lines.'''

        def withoutNewLine(value):
            return ' '.join(line.strip() for line in value.split('\n')) if '\n' in value else value

        return ((key.lower(), withoutNewLine(value)) for key, value in self.items())

    def recursiveHeaders(self):
        '''Walk inside the message, merge found headers. Useful for multipart messages. Be careful that it can
        include the same header more than once.'''

        return [item for part in self.walk() for item in part.headers()]

    def splitSubmessage(self):
        '''Search for messages inside the message payload.'''

        splitPayload = self.plainText().split('\n')

        for num, line in enumerate(splitPayload):
            if not line.strip():
                message = parseMessage('\n'.join(splitPayload[(num + 1):]))
                if message:
                    return '\n'.join(splitPayload[:num]), message

    def plainTextWithoutQuote(self):
        '''Return the plainText() without the lines start with ">".'''

        return '\n'.join(line for line in self.plainText().split('\n') if not line.startswith('>'))
