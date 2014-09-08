.. image:: web/static/logo.png

An application to maintain a mailing list, send bulk mails.


Dependencies
------------

These are required for the application:

* PostgreSQL 9.2 with contrib and Python
* Python 2.7 or 3.3 with standard library
* Psycopg2 2.5
* Flask 0.10

Use Python 3, if you need unicode support.

These are required for installation:

* uWSGI 2.0
* Nginx 1.6


Installation
------------

First of all, a PostgreSQL database is required. The scripts under the db/ directory should be executed
in order.  db/003-emailHash.sql includes the hash function for user URL's.  Is is better to change the secrets
in it, before.  Executing only the new scripts should be sufficient for upgrading.  All of the scripts can be
executed in order like this::

    $ (echo ' Begin;'; cat db/*.sql; echo 'Commit;') | psql mailer

All configuration parameters of the application are optional. PostgreSQL connection parameters can be given
as environment variables via libpg. See http://www.postgresql.org/docs/current/static/libpq-envars.html for
the list.  Flesk configuration parameters can be given as environment variables with FLESK_ prefix. See
http://flask.pocoo.org/docs/config/ for the default ones.

There are separate web servers under the web/ directory.  One of them is for users to redirect, unsubscribe...
One is a RESTful API for other applications.  Other one is for administrators to list emails, send new ones...
They can be run directly for testing::

    $ PGDATABASE=mailer web/admin.py

Running standalone web servers is intended only for development.  Init script and uWSGI configurations provided
under the etc/ directory.  Copy and edit them for installation::

    # mkdir /etc/mailer
    
    # cp etc/uwsgi.conf /etc/mailer/

    # cp etc/linux.init.sh /etc/init.d/mailer

It is better to serve the application behind a general purpose web server.  Nginx is a good choice because it
can pass the requests with uwsgi.  The most simple Nginx virtual server configuration can be like this::

    server {
        listen      80;

        location / {
            include     uwsgi_params;
            uwsgi_pass  unix:/var/run/tart-mailer.sock;
        }
    }

Currently authentication is not included for the admin pages.  It is advised to secure the admin/ location
on the web server. 

Email messages are send and received asynchronously.  Executables under worker/ directory should be run
periodically, to process the messages waiting to be sent or received.  Command line arguments of the executables
can be listed by::

    $ worker/send.py --help

    $ worker/receive.py --help

Cron daemon can be used to run the workers in the background.  See etc/crontab for example.


License
-------

This tool is released under the ISC License, whose text is included to the source files.  The ISC License is
registered with and approved by the Open Source Initiative [1].

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

Version 2.0

* Improve send bulk email performance
* Move locales to emails
* Store subscriber status
* Add email and email variation status
* Decide variations while sending messages
* Do not allow null on locale, use C as the default locale

Version 2.1

* Store email message status
* Improve statistics views
* Send messages in order
* Add --offset to sent worker for concurrency

Version 2.2

* Fix Python 3 compatibility issues
* Add Return-Path and Reply-To fields
* Provide installation instructions
