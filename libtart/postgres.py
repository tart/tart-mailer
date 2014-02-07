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
import psycopg2.extras

psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

class Postgres(psycopg2.extensions.connection):

    def __init__(self, dsn=''):
        psycopg2.extensions.connection.__init__(self, dsn)

        psycopg2.extras.register_hstore(self)

    def __execute(self, query, parameters, table):
        '''Execute a query on the database; return None, the value of the cell, the values in the row in
        a dictionary or the values of the rows in a list of dictionary.'''

        with self.cursor() as cursor:
            cursor.execute(query, parameters)
            rows = cursor.fetchall()
            columnNames = [desc[0] for desc in cursor.description]

        if table:
            return [dict(zip(columnNames, row)) for row in rows]

        if len(rows) == 0:
            raise PostgresException('Query does not return any rows.')

        if len(rows) > 1:
            raise PostgresException('Query returned more than one row.')

        if len(columnNames) > 1:
            return dict(zip(columnNames, rows[0]))

        if rows and columnNames:
            return rows[0][0]

    def call(self, functionName, parameters=[], table=False):
        '''Call a function inside the database with the given arguments.'''

        query = 'Select * from ' + functionName + '('
        if isinstance(parameters, dict):
            query += ', '.join(k + ' := %s' for k in parameters.keys())
            parameters = parameters.values()
        elif hasattr(parameters, '__iter__'):
            query += ', '.join(['%s'] * len(parameters))
        else:
            query += '%s'
            parameters = [parameters]
        query += ')'

        return self.__execute(query, parameters, table)

    def select(self, tableName, whereCondition={}, table=True):
        '''Execute a select query from a single table.'''

        query = 'Select * from ' + tableName
        if whereCondition:
            query += ' where ' + ' and '.join(k + ' = %s' for k in whereCondition.keys())

        return self.__execute(query, whereCondition.values(), table)

    def insert(self, tableName, setColumns, table=False):
        '''Execute an insert one row to a single table.'''

        query = 'Insert into ' + tableName + ' (' + ', '.join(setColumns.keys()) + ')'
        query += ' values (' + ', '.join(['%s'] * len(setColumns)) + ')'
        query += ' returning *'
        print(query)

        return self.__execute(query, setColumns.values(), table)

    def update(self, tableName, setColumns, whereCondition={}, table=True):
        '''Execute an update for a single table.'''

        query = 'Update ' + tableName + ' set ' + ', '.join(k + ' = %s' for k in setColumns.keys())
        parameters = setColumns.values()
        if whereCondition:
            query += ' where ' + ' and '.join(k + ' = %s' for k in whereCondition.keys())
            parameters += whereCondition.values()
        query += ' returning *'

        return self.__execute(query, parameters, table)

class PostgresException(Exception): pass

