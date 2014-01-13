An application to maintain a mailing list, send bulk mails.

Dependencies
------------

* PostgreSQL 9.3 with contrib
* Python 2.6 or greater with standart library
* Psycopg2 2.5
* Flask 0.10

Usage
-----

Copy the default configuration file and edit.

Create a PostgreSQL database and execute the scripts under the db/ directory in order. Change the secrets
on db/003-emailHash.sql before. Execute the only the new scripts ones if you are upgrading.

Test the web server for users:

./userweb.py --debug

Test the web server for administrators:

./adminweb.py --debug

Test sending a mail:

./worker.py --send 1

See deployment page of the Flask documentation [1] to run the web servers with Nginx and uWSGI. Command line
arguments cannot be set with uWSGI. Use the chdir directive of uWSGI to use the configuration with default name
on the given path. There are example configurations under conf/ directory.

[1] http://flask.pocoo.org/docs/deploying/uwsgi/

License
-------

This tool is released under the ISC License, whose text is included to the
source files. The ISC License is registered with and approved by the
Open Source Initiative [1].

[1] http://opensource.org/licenses/isc-license.txt

