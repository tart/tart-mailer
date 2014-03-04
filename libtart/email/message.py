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
                assert len(self.get_payload()) > 1

                if splitType[1] in ('report', 'mixed'):
                    # Sanity checks for response reports and multipart emails supposed to include the returned
                    # original according to RFC 2464 page 7.

                    assert len(self.get_payload()) <= 3

                    # The last content type must be the returned original.
                    assert self.get_payload()[-1].get_content_type() in ('message/rfc822', 'text/rfc822-headers')

                    if len(self.get_payload()) > 2:
                        # The one before the returned original must be one of the standart responses.
                        assert self.get_payload()[-2].get_content_type() in ('message/delivery-status',
                                                                             'message/feedback-report')

            for payload in self.get_payload():
                payload.check()

        elif splitType[0] == 'text':
            # Sanity checks plain text emails.
            assert not self.is_multipart()

    def plainest(self):
        '''Return the text/plain payload or first payload inside multipart/alternative message which should
        be the plainest according to RFC 2046 page 24.'''

        if self.is_multipart():
            return self.get_payload(0).plainest()
        return self.get_payload()

    def headers(self):
        '''Return headers with lower case names and without new lines.'''

        def withoutNewLine(value):
            return ' '.join(line.strip() for line in value.split('\n'))

        return ((key.lower(), withoutNewLine(value)) for key, value in self.items())

    def recursiveHeaders(self):
        '''Walk inside the message, merge found headers. Useful for multipart messages. Be careful that it can
        include the same header more than once.'''

        return [item for part in self.walk() for item in part.headers()]

    def splitSubmessage(self):
        '''Search for messages inside the message payload.'''

        splitPayload = self.plainest().split('\n')

        for num, line in enumerate(splitPayload):
            if not line.strip():
                submessage = email.message_from_string('\n'.join(splitPayload[(num + 1):]), Message)
                if len(submessage.items()) > 2:
                    # Consider it a valid submessage if there are more than 2 headers.
                    return '\n'.join(splitPayload[:num]), submessage

    def plainestWithoutQuote(self):
        '''Return the plainest() without the lines start with ">".'''

        return '\n'.join(line for line in self.plainest().split('\n') if not line.startswith('>'))
