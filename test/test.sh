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
echo "\Copy Project (name, fromName, emailAddress, returnURLRoot) from 'project.data';
\Copy Subscriber (projectName, emailAddress, properties) from 'subscriber.data';
\Copy Email (projectName, redirectURL, outgoingServerName) from 'email.data';
Create temp table TempEmailVariation (subject varchar(1000), plainBody text, hTMLBody text);
\Copy TempEmailVariation from 'emailvariation.data';
Insert into EmailVariation (emailId, subject, plainBody, hTMLBody) select Email.id, TempEmailVariation.* from Email, TempEmailVariation;
Insert into EmailSend (emailId, subscriberId, variationRank) select EmailVariation.emailId, Subscriber.id, EmailVariation.rank from EmailVariation, Subscriber;" | psql
echo

echo "Trying to send an email..."
../worker.py --send 1 --outgoing-server localhost --timeout 10
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

echo "Trying to view..."
curl http://localhost:8000/view/$emailHash
echo
echo

echo "Killing the web server..."
trap "kill 0" SIGINT SIGTERM EXIT
