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

from __future__ import absolute_import

import re

import psycopg2.extensions
import psycopg2.extras

from libtart.helpers import singleton
from libtart.collections import OrderedCaseInsensitiveDict

# These are not necessary with Python 3.
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

debug = False

@singleton
class connection(psycopg2.extensions.connection):
    """The purpose of the class is to add practical functions to the connection class on the psycopg2 library.
    Unlike the parent class autocommit enabled by default but it will be disabled on demand."""

    def __init__(self, dsn=''):
        psycopg2.extensions.connection.__init__(self, dsn)
        self.set_client_encoding('utf8')
        self.autocommit = True
        psycopg2.extras.register_hstore(self)
        self.__registerCompositeTypes()

    def __registerCompositeTypes(self):
        for row in self.__execute('''
Select typname
    from pg_type
        where typcategory = 'C'
                and (typnamespace in (select oid
                            from pg_namespace
                                where nspname !~ 'pg_*'
                                        and nspname != 'information_schema')
                        or typname = 'record')'''):
            psycopg2.extras.register_composite(str(row['typname']), self, factory=OrderedCaseInsensitiveDictComposite)

    def __enter__(self):
        self.autocommit = False
        return psycopg2.extensions.connection.__enter__(self)

    def __exit__(self, *args):
        psycopg2.extensions.connection.__exit__(self, *args)
        self.autocommit = True

    def cursor(self, *args, **kwargs):
        kwargs.setdefault('cursor_factory', OrderedCaseInsensitiveDictCursor)
        return psycopg2.extensions.connection.cursor(self, *args, **kwargs)

    def __execute(self, query, parameters=[], table=True):
        """Execute a query on the database; return None, the value of the cell, the values in the row in
        a dictionary or the values of the rows in a list of dictionary."""

        with self.cursor() as cursor:
            if debug:
                print('QUERY: ' + str(cursor.mogrify(query, list(parameters))))

            try:
                cursor.execute(query, list(parameters))
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
        elif isinstance(parameters, list) or isinstance(parameters, tuple):
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

    def select(self, tableName, where={}, orderBy=None, limit=None, offset=None, table=True):
        """Execute a select query from a single table."""

        query = 'Select * from ' + tableName + self.whereClause(where)
        if orderBy:
            if isinstance(orderBy, tuple):
                query += ' order by ' + ', '.join(orderBy)
            else:
                query += ' order by ' + str(orderBy)
        if limit:
            query += ' limit ' + str(limit)
        if offset:
            query += ' offset ' + str(offset)

        return self.__execute(query, where.values(), table)

    def selectOne(self, *args, **kwargs):
        return self.select(*args, table=False, **kwargs)

    def exists(self, tableName, where={}):
        """Execute a select exists() query for a single table."""

        query = 'Select exists(select 1 from ' + tableName + self.whereClause(where) + ')'
        return self.__execute(query, where.values(), False)

    def insert(self, tableName, values):
        """Execute an insert one row or several rows to a single table."""

        if isinstance(values, dict):
            columns = values.keys()
            values = (values,)
        else:
            columns = set(k.lower() for n in values for k in n.keys())

        query = 'Insert into ' + tableName + ' (' + ', '.join(columns) + ') values '
        query += ', '.join('(' + ', '.join('%s' if c in v else 'default' for c in columns) + ')' for v in values)
        query += ' returning *'

        return self.__execute(query, [v[c] for v in values for c in columns if c in v], len(values) > 1)

    def insertIfNotExists(self, tableName, values):
        """Execute an insert into select query to insert a single row to a single table."""

        query = 'Insert into ' + tableName + ' (' + ', '.join(values.keys()) + ')'
        query += ' select ' + ', '.join('%s' for v in values)
        query += ' where not exists(select 1 from ' + tableName + self.whereClause(values) + ')'
        query += ' returning *'

        try:
            return self.__execute(query, list(values.values()) * 2, False)
        except NoRow:
            return None

    def update(self, tableName, setColumns, where={}, table=True):
        """Execute an update for a single table."""

        assert setColumns
        query = 'Update ' + tableName + ' set ' + ', '.join(k + ' = %s' for k in setColumns.keys())
        query += self.whereClause(where) + ' returning *'

        return self.__execute(query, list(setColumns.values()) + list(where.values()), table)

    def updateOne(self, *args, **kwargs):
        return self.update(*args, table=False, **kwargs)

    def upsert(self, tableName, setColumns, where={}):
        try:
            return self.updateOne(tableName, setColumns, where)
        except NoRow:
            return self.insert(tableName, OrderedCaseInsensitiveDict(list(setColumns.items()) + list(where.items())))

    def delete(self, tableName, where={}, table=True):
        """Execute a delete for a single table."""

        query = 'Delete from ' + tableName + self.whereClause(where)
        query += ' returning *'

        return self.__execute(query, where.values(), table)

    def deleteOne(self, *args, **kwargs):
        return self.delete(*args, table=False, **kwargs)

    def whereClause(self, conditions):
        query = ''
        for key, value in conditions.items():
            if not query:
                query += ' where'
            else:
                query += ' and'
            query += ' ' + key
            if isinstance(value, dict):
                query += ' @> %s'
            elif isinstance(value, list):
                query += ' = any (%s)'
            elif value is None:
                query += ' is not distinct from %s'
            else:
                query += ' = %s'
        return query

    def truncate(self, tableName):
        """Execute a truncate."""

        return self.__execute('Truncate ' + tableName, [], True)

class OrderedCaseInsensitiveDictCursor(psycopg2.extras.RealDictCursor):
    def __init__(self, *args, **kwargs):
        kwargs['row_factory'] = OrderedCaseInsensitiveDictRow
        super(psycopg2.extras.RealDictCursor, self).__init__(*args, **kwargs)
        self._prefetch = 0


class OrderedCaseInsensitiveDictRow(psycopg2.extras.RealDictRow, OrderedCaseInsensitiveDict):
    """Inspired by the structure on the psycopg2 library.
    See: https://github.com/psycopg/psycopg2/blob/master/lib/extras.py
    """

    def __init__(self, cursor):
        OrderedCaseInsensitiveDict.__init__(self)

        # Required for named cursors
        if cursor.description and not cursor.column_mapping:
            cursor._build_index()
        self._column_mapping = cursor.column_mapping

    def __setitem__(self, name, value):
        if type(name) == int:
            name = self._column_mapping[name]
        return OrderedCaseInsensitiveDict.__setitem__(self, name, value)

class OrderedCaseInsensitiveDictComposite(psycopg2.extras.CompositeCaster, OrderedCaseInsensitiveDict):
    def make(self, values):
        return OrderedCaseInsensitiveDict(zip(self.attnames, values))

class NoRow(Exception): pass

class MoreThanOneRow(Exception): pass

class PostgresError(Exception):
    def __init__(self, psycopgError):
        Exception.__init__(self, psycopgError.diag.message_primary)
        self.__psycopgError = psycopgError

    def details(self):
        return dict((attr, getattr(self.__psycopgError.diag, attr))
                    for attr in dir(self.__psycopgError.diag)
                    if not attr.startswith('__') and getattr(self.__psycopgError.diag, attr) is not None)

class ProgrammingError(PostgresError): pass

class IntegrityError(PostgresError): pass
