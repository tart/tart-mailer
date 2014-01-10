An application to maintain a mailing list, send bulk mails.

Dependencies
------------

* PostgreSQL 9.3 with hstore
* Python 3.3
* Psycopg2 2.5
* Flask 0.10

Usage
-----

Copy the default configuration file and edit.

Execute the scripts under the db directory on PostgreSQL in order. Change the secrets on db/003-emailHash.sql before.
Execute the only the new scripts ones if you are upgrading.

Test the web server:

./webserver.py --debug

Test sending a mail:

./worker.py --send 1

License
-------

This tool is released under the ISC License, whose text is included to the
source files. The ISC License is registered with and approved by the
Open Source Initiative [1].

[1] http://opensource.org/licenses/isc-license.txt

