#!/bin/bash -e

export PGDATABASE=mailertest

echo "Running the web server for users..."
../web/user.py &
sleep 3
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
