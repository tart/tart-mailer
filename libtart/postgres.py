# -*- coding: utf-8 -*-
##
# Tart Library - PostgreSQL Access Layer
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

import psycopg2.extensions

class Postgres(psycopg2.extensions.connection):

    def __functionCallQuery(self, function, *args, **kwargs):
        '''Generate a query to call a function with the given arguments.'''
        query = 'Select * from ' + function + '('
        query += ', '.join(['%s'] * len(args))
        query += ', '.join(k + ' := %s' for k in kwargs.keys())
        query += ')'

        return query, list(args) + list(kwargs.values())

    def call(self, *args, **kwargs):
        '''Call a function inside the database, do not return anything.'''
        with self.cursor() as cursor:
            cursor.execute(*self.__functionCallQuery(*args, **kwargs))

    def callTable(self, *args, **kwargs):
        '''Call a function inside the database, return the records as dictionaries inside a list.'''
        with self.cursor() as cursor:
            cursor.execute(*self.__functionCallQuery(*args, **kwargs))

            columnNames = [desc[0] for desc in cursor.description]
            return (dict(zip(columnNames, v)) for v in cursor.fetchall())

    def callOneLine(self, function, *args, **kwargs):
        '''Call a function inside the database return the first line.'''
        with self.cursor() as cursor:
            cursor.execute(*self.__functionCallQuery(function, *args, **kwargs))

            line = cursor.fetchone()
            columnNames = [desc[0] for desc in cursor.description]
            return dict(zip(columnNames, line or []))

    def callOneCell(self, function, *args, **kwargs):
        '''Call a function inside the database return the first cell.'''
        with self.cursor() as cursor:
            cursor.execute(*self.__functionCallQuery(function, *args, **kwargs))

            line = cursor.fetchone()
            if line:
                for cell in line:
                    return cell

class PostgresException(Exception): pass

