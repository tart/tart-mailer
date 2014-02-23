.. image:: logo.png

An application to maintain a mailing list, send bulk mails.

Dependencies
------------

* PostgreSQL 9.2 with contrib and Python
* Python 2.6 or 3.3 with standart library
* Psycopg2 2.5
* Flask 0.10

Installation
------------

All configuration parameters are optional. PostgreSQL connection parameters can be given as environment variables
via libpg. See http://www.postgresql.org/docs/current/static/libpq-envars.html for the list.

Flesk configuration parameters can be given as environment variables with FLESK_ prefix. See
http://flask.pocoo.org/docs/config/ for the default ones.

A seperate PostgreSQL database is required. The scripts under the db/ directory should be executed in order.
db/003-emailHash.sql includes the hash function for user URL's. Is is better to change the secrets in it, before.
Executing only the new scripts should be sufficient for upgrading. All of the scripts can be executed in order like
this::

    cat db/* | psql

There are two seperate web servers. One of them is for users to redirect, unsubscribe... Other one is for
administratiors to list emails, send new ones... They both can be run directly::

    web/user.py

    web/admin.py

Emailes are send and received asynchronously. Executables under worker/ directory should be run periodically. Command
line arguments will be listed by::

    worker/send.py --help

    worker/receive.py --help

See deployment page of the Flask documentation [1] to run the web servers with Nginx and uWSGI. There are
example configurations under the conf/ directory. Also, there is a test script under the test/ directory.

[1] http://flask.pocoo.org/docs/deploying/uwsgi/

License
-------

This tool is released under the ISC License, whose text is included to the
source files. The ISC License is registered with and approved by the
Open Source Initiative [1].

[1] http://opensource.org/licenses/isc-license.txt

Coding Style
------------

In PostgreSQL, relation names are case-insensitive when they are not in double quotes. PostgreSQL returns
them in lower-case. That is why column names, which will be keys of the dictionaries, are lower-case. This
rule should be kept even the dictionary is not return from the database, for convenience. HTML forms are
also mapped to dictionaries. Input names on the forms should also be lower-case as they will be the keys
of the dictionaries.

Known Issues
------------

Duplicate headers of the response reports are not saved to the database.
