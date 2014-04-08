#!/bin/bash -e

test "$PGDATABASE" || PGDATABASE=$USER

echo "Creating database..."
echo "Drop database if exists $PGDATABASE" | psql postgres
echo "Create database $PGDATABASE" | psql postgres
echo

echo "Executing the database scripts..."
(echo 'Begin;'; cat ../db/*; echo 'Commit') | psql
echo

echo "Adding data..."
echo "\Copy Sender (fromAddress, fromName, returnURLRoot) from 'sender.data';
\Copy Subscriber (fromAddress, toAddress, properties) from 'subscriber.data';
\Copy Email (fromAddress, redirectURL) from 'email.data';
Create temp table TempEmailVariation (subject varchar(1000), plainBody text, hTMLBody text);
\Copy TempEmailVariation from 'emailvariation.data';
Insert into EmailVariation (fromAddress, emailId, subject, plainBody, hTMLBody)
    select Email.fromAddress, Email.emailId, TempEmailVariation.*
        from Email, TempEmailVariation;
Select SendTestEmail(Subscriber.fromAddress, Subscriber.toAddress, EmailVariation.emailId, EmailVariation.variationId)
    from Subscriber, EmailVariation;" | psql
echo
