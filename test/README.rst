Regression test for tart-mailer. Currently test does not include web server for administrators.

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

Add tab seperated emails to the file named email.data.

Add tab seperated subscribers to the file named subscriber.data. Only one email will be send and feedback
functionality will be tested for this one. The email and the subscriber will be the ones on top of the list.

Run the script inside this directory:

./test.sh

