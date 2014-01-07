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

import psycopg2

class Postgres:
    def __init__(self, *args, **kwargs):
        '''Initialize connection to the database.'''
        self.__connection = psycopg2.connect(*args, **kwargs)

    def __del__(self):
        '''Close connection to the database.'''
        if self.__connection:
            self.__connection.close()

    def call(self, function, *args, **kwargs):
        '''Call a function inside the database.'''

        with self.__connection, self.__connection.cursor() as cursor:
            cursor.execute('Select * from ' + function + '(' + ', '.join(['%s'] * len(args)) +
                           ', '.join(k + ' := %s' for k in kwargs.keys()) + ')',
                           list(args) + list(kwargs.values()))

            columnNames = [desc[0] for desc in cursor.description]
            return (dict(zip(columnNames, v)) for v in cursor.fetchall())

    def callOneLine(self, function, *args, **kwargs):
        for line in self.call(function, *args, **kwargs):
            return line

        raise PostgresException('No lines returned from the function ' + function + '.')

class PostgresException(Exception): pass

