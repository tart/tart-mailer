Regression test for tart-mailer.

Dependencies
------------

* bash
* psql
* curl

Usage
-----

Copy the default configuration file to the test directory and edit. Do not give an used database to the configuration.
It will be dropped and recreated by the script. Note that parameters except dbname will not be used by the psql
statements inside the test script.

Add tab seperated emails as to email.data.

Add tab seperated subscribers as to subscriber.data. Emails will be send to the top 5 subscribers. Add valid email
addresses to them.

Run the script inside this directory:

./test.sh

