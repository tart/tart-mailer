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

os.sys.path.append(os.path.join(os.path.dirname(os.path.realpath(__file__)), '..'))
from libtart import postgres

def main():
    import xml.etree.cElementTree as ElementTree

    with postgres.connection() as transaction:
        transaction.truncate('DMARCReportRow')

        for report in transaction.select('DMARCReport'):
            tree = ElementTree.fromstring(report['body'])

            for record in tree.iter('record'):
                transaction.insert('DMARCReportRow', {
                    'reporterAddress': report['reporteraddress'],
                    'reportId': report['reportid'],
                    'source': record.find('row/source_ip').text,
                    'messageCount': record.find('row/count').text,
                    'disposition': record.find('row/policy_evaluated/disposition').text,
                    'dKIMPass': record.find('row/policy_evaluated/dkim').text == 'pass',
                    'sPFPass': record.find('row/policy_evaluated/spf').text == 'pass',
                })

if __name__ == '__main__':
    main()
