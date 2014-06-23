#!/bin/bash -e

test "$PGDATABASE" || PGDATABASE=$USER

echo "Creating database..."
echo "Drop database if exists $PGDATABASE" | psql postgres
echo "Create database $PGDATABASE" | psql postgres
echo

echo "Executing the database scripts..."
(echo 'Begin;'; cat ${0%/*}/../db/*.sql; echo 'Commit') | psql
echo

echo "Adding data..."
echo "\Copy Sender (fromAddress, password, fromName, returnURLRoot) from '${0%/*}/sender.data';
\Copy Subscriber (fromAddress, toAddress, properties) from '${0%/*}/subscriber.data';
\Copy Email (fromAddress, name, redirectURL) from '${0%/*}/email.data';
Create temp table TempEmailVariation (subject varchar(1000), plainBody text, hTMLBody text);
\Copy TempEmailVariation from '${0%/*}/emailvariation.data';
Insert into EmailVariation (fromAddress, emailId, subject, plainBody, hTMLBody)
    select Email.fromAddress, Email.emailId, TempEmailVariation.*
        from Email, TempEmailVariation;
Insert into EmailSend (fromAddress, toAddress, emailId, variationId)
    select Subscriber.fromAddress, Subscriber.toAddress, EmailVariation.emailId, EmailVariation.variationId
        from Subscriber, EmailVariation;" | psql
echo
