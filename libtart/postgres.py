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

import collections
import psycopg2.extensions
import psycopg2.extras

from libtart.helpers import singleton

# These are not necessary with Python 3.
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

debug = False

@singleton
class connection(psycopg2.extras.RealDictConnection):
    """The purpose of the class is to add practical functions to the connection class on the psycopg2 library.
    Unlike the parent class autocommit enabled by default but it will be disabled on demand."""

    def __init__(self, dsn=''):
        psycopg2.extensions.connection.__init__(self, dsn)
        self.autocommit = True
        psycopg2.extras.register_hstore(self)

    def __enter__(self):
        self.autocommit = False
        return psycopg2.extensions.connection.__enter__(self)

    def __exit__(self, *args):
        psycopg2.extensions.connection.__exit__(self, *args)
        self.autocommit = True

    def __execute(self, query, parameters, table):
        """Execute a query on the database; return None, the value of the cell, the values in the row in
        a dictionary or the values of the rows in a list of dictionary."""

        if debug:
            print('QUERY: ' + query)

        with self.cursor() as cursor:
            try:
                cursor.execute(query, parameters)
            except psycopg2.ProgrammingError as error:
                raise ProgrammingError(error)
            except psycopg2.IntegrityError as error:
                raise IntegrityError(error)

            if table:
                if cursor.rowcount > 0:
                    return cursor.fetchall()

                return []

            if cursor.rowcount == 0:
                raise NoRow('Query does not return any rows.')

            if cursor.rowcount > 1:
                raise MoreThanOneRow('Query returned more than one row.')

            if len(cursor.description) == 1:
                for cell in cursor.fetchone().values():
                    return cell

            if len(cursor.description) > 1:
                return cursor.fetchone()

    def call(self, functionName, parameters=[], table=False):
        """Call a function inside the database with the given arguments."""

        query = 'Select * from ' + functionName + '('
        if isinstance(parameters, dict):
            query += ', '.join(k + ' := %s' for k in parameters.keys())
            parameters = parameters.values()
        elif hasattr(parameters, '__iter__'):
            query += ', '.join(['%s'] * len(parameters))
        elif parameters is None:
            parameters = []
        else:
            query += '%s'
            parameters = [parameters]
        query += ')'

        return self.__execute(query, parameters, table)

    def callTable(self, *args):
        return self.call(*args, table=True)

    def select(self, tableName, whereConditions={}, table=True):
        """Execute a select query from a single table."""

        query = 'Select * from ' + tableName
        if whereConditions:
            query += ' where ' + ' and '.join(k + ' = %s' for k in whereConditions.keys())

        return self.__execute(query, whereConditions.values(), table)

    def selectOne(self, *args):
        return self.select(*args, table=False)

    def insert(self, tableName, setColumns):
        """Execute an insert one row to a single table."""

        query = 'Insert into ' + tableName + ' (' + ', '.join(setColumns.keys()) + ')'
        query += ' values (' + ', '.join(['%s'] * len(setColumns)) + ')'
        query += ' returning *'

        return self.__execute(query, setColumns.values(), False)

    def update(self, tableName, setColumns, whereConditions={}, table=True):
        """Execute an update for a single table."""

        query = 'Update ' + tableName + ' set ' + ', '.join(k + ' = %s' for k in setColumns.keys())
        parameters = setColumns.values()

        if whereConditions:
            query += ' where ' + ' and '.join(k + ' = %s' for k in whereConditions.keys())
            parameters += whereConditions.values()
        query += ' returning *'

        return self.__execute(query, parameters, table)

    def updateOne(self, *args):
        return self.update(*args, table=False)

    def delete(self, tableName, whereConditions={}, table=True):
        """Execute a delete for a single table."""

        query = 'Delete from ' + tableName
        parameters = []
        if whereConditions:
            query += ' where ' + ' and '.join(k + ' = %s' for k in whereConditions.keys())
            parameters += whereConditions.values()
        query += ' returning *'

        return self.__execute(query, parameters, table)

    def truncate(self, tableName):
        """Execute a truncate."""

        return self.__execute('Truncate ' + tableName, [], True)

class NoRow(Exception): pass

class MoreThanOneRow(Exception): pass

class PostgresError(StandardError):
    def __init__(self, psycopgError):
        StandardError.__init__(self, psycopgError.diag.message_primary)
        self.__psycopgError = psycopgError

    def details(self):
        return dict((attr, getattr(self.__psycopgError.diag, attr))
                    for attr in dir(self.__psycopgError.diag)
                    if not attr.startswith('__') and getattr(self.__psycopgError.diag, attr) is not None)

class ProgrammingError(PostgresError): pass

class IntegrityError(PostgresError): pass
