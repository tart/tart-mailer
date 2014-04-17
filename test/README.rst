Regression test for tart-mailer. Currently test does not cover the web server for administrators.

Dependencies
------------

* bash
* psql
* curl

Usage
-----

PostgreSQL connection parameters can also be given as environment variables. The database will be dropped
re-created by the script 000-db.sh. It will be the database with that same name of the current user, if the
environment variable PGDATABASE does not set. It should be the database will be used by the other scripts.

Tab seperated files emails.data and subscribers.data will be loaded to the database. Only one email will be send
and feedback functionality will be tested for this one. The email and the subscriber will be the ones on top of
the list.

Run the scripts in order::

    ./000-db.sh

    ./001-send.sh

    ./002-user.sh

    ./003-api.sh
