Regression test for tart-mailer. Currently test does not cover the web server for administrators.

Dependencies
------------

* bash
* psql
* curl

Usage
-----

A PostgreSQL database named "mailertest" will be dropped and recreated by the script. Other PostgreSQL connection
parameters can be given as environment variables.

Tab seperated files emails.data and subscribers.data will be loaded to the database. Only one email will be send
and feedback functionality will be tested for this one. The email and the subscriber will be the ones on top of
the list.

Run the scripts inside this directory in order::

    ./000-db.sh

    ./001-send.sh

    ./002-user.sh
