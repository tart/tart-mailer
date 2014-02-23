# -*- coding: utf-8 -*-
##
# Tart Library - Helper Functions
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

from __future__ import absolute_import, print_function

import sys

def printWarning(message, level=0):
    if isinstance(message, dict):
        print(file=sys.stderr)
        for key, value in message.items():
            print('\t' * (level + 1), end='', file=sys.stderr)
            printWarning([key + ':', value], level=(level + 1))
            print(file=sys.stderr)

    elif isinstance(message, list) or isinstance(message, tuple):
        for item in message:
            printWarning(item, level=level)

    else:
        message = str(message).strip('\n')

        if '\n' in message:
            print(file=sys.stderr)
            for line in message.split('\n'):
                print(('\t' * (level + 1)) + line, file=sys.stderr)

        else:
            print(message, end=' ', file=sys.stderr)

def warning(*messages):
    printWarning(['WARNING:', messages])

    print(file=sys.stderr)
