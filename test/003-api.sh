#!/bin/bash -e

echo "Running the web server for API..."
${0%/*}/../web/api.py &
sleep 3
echo

#
# Methods
#

echo "Trying to add a subscriber..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X POST -d '
    {
        "toAddress": "osman@spam.bo",
        "properties": {
            "eyeColor": "brown",
            "gender": "male"
        }
    }' http://localhost:8080/subscriber
echo
echo

echo "Trying to update the subscriber..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X PUT -d '
    {
       "locale": "tr_TR"
    }' http://localhost:8080/subscriber/osman@spam.bo
echo
echo

echo "Trying to list the subscribers..."
curl -u tart-mailer@github.com:secret http://localhost:8080/subscriber
echo
echo

echo "Trying to send an email to the suscriber..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X POST -d '
    {
        "redirectURL": "http://click.xxx/?from=mailer",
        "subject": "Click this link!",
        "plainBody": "Click: {redirecturl}",
        "hTMLBody": "<h1>XXX</h1><p><a href=\"{redirecturl}\">click</a></p>"
    }' http://localhost:8080/subscriber/osman@spam.bo/send
echo
echo

echo "Trying to get send messages..."
curl -u tart-mailer@github.com:secret http://localhost:8080/email/send
echo
echo

#
# Errors
#

echo "Trying to add a subscriber with invalid fields..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X POST -d '
    {
        "toAddress": "osman@spam.bo",
        "gender": "male"
    }' http://localhost:8080/subscriber
echo
echo

echo "Trying an XML request..."
curl -H "Content-type: application/xml" -u tart-mailer@github.com:secret -X POST -d '
<xml></xml>' http://localhost:8080/subscriber
echo
echo

echo "Trying a request with a JSON array..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X POST -d '
    [
        {"toAddress": "invalid1@example.com"},
        {"fromAddress": "invalid2@example.com"}
    ]' http://localhost:8080/subscriber
echo
echo

echo "Trying a valid address without authentication..."
curl -H "Content-type: application/json" http://localhost:8080/subscriber
echo
echo

echo "Trying an address that does not exists..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret http://localhost:8080/doesNotExists
echo
echo

echo "Trying a not allowed method..."
curl -H "Content-type: application/json" -X POST http://localhost:8080/subscriber/osman@spam.bo
echo
echo

echo "Trying to send an email to the previously unsubscribed address..."
curl -H "Content-type: application/json" -u tart-mailer@github.com:secret -X POST -d '
    {
        "redirectURL": "http://click.xxx/?from=mailer",
        "subject": "Click this link!",
        "plainBody": "Click: {redirecturl}",
        "hTMLBody": "<h1>XXX</h1><p><a href=\"{redirecturl}\">click</a></p>"
    }' http://localhost:8080/subscriber/me@mydomain/send
echo
echo

echo "Killing the web server..."
trap "kill 0" SIGINT SIGTERM EXIT
