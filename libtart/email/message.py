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

from __future__ import absolute_import

import email
import email.message

class Message(email.message.Message):
    '''Extend the Message class on the standart library.'''

    def check(self):
        splitType = self.get_content_type().split('/')

        if splitType[0] in ('multipart', 'message'):
            assert self.is_multipart()

            if splitType[0] == 'multipart':
                if splitType[1] in ('report', 'mixed'):
                    # Sanity checks for response reports and multipart emails supposed to include the returned
                    # original according to RFC 2464 page 7.

                    assert len(self.get_payload()) <= 3

                    # The last content type must be the returned original.
                    assert self.get_payload()[-1].get_content_type() == 'message/rfc822'

                    if len(self.get_payload()) > 2:
                        # The one before the returned original must be one of the standart responses.
                        assert self.get_payload()[-2].get_content_type() in ('message/delivery-status',
                                                                             'message/feedback-report')

            elif splitType[0] == 'message':
                assert len(self.get_payload()) == 1

            for payload in self.get_payload():
                payload.check()

        else:
            assert not self.is_multipart()

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

    def splitSubmessage(self):
        '''Search for messages inside the message payload.'''

        splitPayload = self.plainText().split('\n')

        for num, line in enumerate(splitPayload):
            if not line.strip():
                submessage = email.message_from_string('\n'.join(splitPayload[(num + 1):]), Message)
                if len(submessage.items()) > 2:
                    # Consider it a valid submessage if there are more than 2 headers.
                    return '\n'.join(splitPayload[:num]), submessage

    def plainTextWithoutQuote(self):
        '''Return the plainText() without the lines start with ">".'''

        return '\n'.join(line for line in self.plainText().split('\n') if not line.startswith('>'))
