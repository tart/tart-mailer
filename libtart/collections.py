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

from __future__ import absolute_import

import collections

class OrderedCaseInsensitiveDict(collections.OrderedDict):
    """Low performance case in-sensitive dict class.

    Inspired by the structure on the requests library.
    See: https://github.com/kennethreitz/requests/blob/v1.2.3/requests/structures.py#L37
    """

    def __contains__(self, key):
        for k in self.keys():
            if k.lower() == key.lower():
                return True
        return False

    def __getitem__(self, key):
        for k in self.keys():
            if k.lower() == key.lower():
                return collections.OrderedDict.__getitem__(self, k)

    def __setitem__(self, key, value):
        for k in self.keys():
            if k.lower() == key.lower():
                return collections.OrderedDict.__setitem__(self, k, value)
        return collections.OrderedDict.__setitem__(self, key, value)

    def __delitem__(self, key):
        for k in self.keys():
            if k.lower() == key.lower():
                return collections.OrderedDict.__delitem__(self, k)

    def __eq__(self, other):
        if isinstance(other, OrderedCaseInsensitiveDict):
            return collections.OrderedDict(self.lowerItems()) == collections.OrderedDict(other.lowerItems())
        return collections.OrderedDict.__eq__(self, other)

    def lowerItems(self):
        return ((k.lower(), v) for k, v in self.items())

    def subset(self, *args):
        return collections.OrderedDict((k, v) for k, v in self.items() if k.lower() in [a.lower() for a in args])

    def update(self, other):
        for k, v in other.items():
            self.__setitem__(k, v)
