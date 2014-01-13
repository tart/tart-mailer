#!/bin/bash -e

dbname=$(grep dbname mailer.conf | cut -d = -f 2)

echo "Creating database..."
echo "Drop database if exists $dbname" | psql postgres
echo "Create database $dbname" | psql postgres
echo

echo "Executing the database scripts..."
cat ../db/* | psql $dbname
echo

echo "Adding data..."
echo "\Copy Subscriber (fullName, emailAddress, properties) from 'subscriber.data'" | psql $dbname
echo "\Copy Email (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL) from 'email.data'" | psql $dbname
echo "Insert into EmailSend (emailId, subscriberId) select Email.id, Subscriber.id from Email, Subscriber" | psql $dbname
echo

echo "Trying to send emails..."
../worker.py --send 5
echo

echo "Running the web server for users..."
../userweb.py --debug --port 8080 &
sleep 1
echo

emailHash=$(echo "Select EmailHash(EmailSend) from EmailSend limit 1" | psql -XAt $dbname)

echo "Trying to get the tracker image..."
curl http://localhost:8080/trackerImage/$emailHash
echo
echo

echo "Trying to redirect..."
curl http://localhost:8080/redirect/$emailHash
echo
echo

echo "Trying to unsubscribe..."
curl http://localhost:8080/unsubscribe/$emailHash
echo
echo

echo "Killing the web server..."
kill %1

