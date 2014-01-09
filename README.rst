An application to maintain a mailing list, send bulk mails.

Dependencies
------------

* PostgreSQL 9.3 with hstore
* Python 3.3
* Psycopg2 2.5
* Flask 0.10
* Flask-Mail 0.9

Usage
-----

Installation:

* Change the secrets on db/003-emailHash.sql
* Execute the scripts under the db directory in order.

Upgrading:

* Execute the new scripts under the db directory in order.

Testing web server:

./webserver.py

License
-------

This tool is released under the ISC License, whose text is included to the
source files. The ISC License is registered with and approved by the
Open Source Initiative [1].

[1] http://opensource.org/licenses/isc-license.txt

