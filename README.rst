.. image:: web/static/logo.png

An application to maintain a mailing list, send bulk mails.

Dependencies
------------

* PostgreSQL 9.2 with contrib and Python
* Python 2.6 or 3.3 with standart library
* Psycopg2 2.5
* Flask 0.10

Use Python 3, if you need unicode support.

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

    (echo ' Begin;'; cat db/*; echo 'Commit;') | psql

There are seperate web servers. One of them is for users to redirect, unsubscribe... One is a RESTful API for
other applications. Other one is for administrators to list emails, send new ones... They both can be run directly::

    web/user.py

    web/api.py

    web/admin.py

Email messages are send and received asynchronously. Executables under worker/ directory should be run periodically,
to process the messages waiting to be sent or received. Command line arguments of the executables will be listed by::

    worker/send.py --help

    worker/receive.py --help

Running standalone web servers is intended for debugging only. See deployment page of the Flask documentation [1]
to run them in production. There are example configurations under the conf/ directory for Nginx and uWSGI. Also,
there is a test script under the test/ directory.

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

Changelog
---------

Version 1.0

* Improve database schema using more composite keys
* Make the infrastructure suitable to not bulk emails
* Add authentication and authorization to the API
* Allow adding subscribers via admin panel
* Support IMAP4 SSL
* Process DMARC reports

Version 1.1

* Allow filtering subscribers to send bulk emails
* Split bulk email send page
* Improve error handling of the API
* Add more methods to the API
* Add pagination to the API

Version 1.2

* Allow filtering on the API

Version 1.3

* Add locales to email variations
* Improve email variation distribution method
* Fix slow query on the bulk send page with a lot of subscribers
* Show email statistics by subscriber locale
* Add name to emails
* Send messages in random order
* Allow multiple send workers to operate together
