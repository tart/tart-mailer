#!/bin/bash -e

export PGDATABASE=mailertest

echo "Creating database..."
echo "Drop database if exists $PGDATABASE" | psql postgres
echo "Create database $PGDATABASE" | psql postgres
echo

echo "Executing the database scripts..."
cat ../db/* | psql
echo

echo "Adding data..."
echo "\Copy Subscriber (emailAddress, properties) from 'subscriber.data'" | psql
echo "\Copy Email (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL, outgoingServerName) from 'email.data'" | psql
echo "Insert into EmailSend (emailId, subscriberId) select Email.id, Subscriber.id from Email, Subscriber" | psql
echo

echo "Trying to send an email..."
../worker.py
echo

echo "Running the web server for users..."
../userweb.py &
sleep 2
echo

emailHash=$(echo "Select EmailHash(EmailSend) from EmailSend limit 1" | psql -XAt $dbname)

echo "Trying to get the tracker image..."
curl http://localhost:8000/trackerImage/$emailHash
echo
echo

echo "Trying to redirect..."
curl http://localhost:8000/redirect/$emailHash
echo
echo

echo "Trying to unsubscribe..."
curl http://localhost:8000/unsubscribe/$emailHash
echo
echo

echo "Killing the web server..."
trap "kill 0" SIGINT SIGTERM EXIT

