#!/bin/bash -e

export PGDATABASE=mailertest

echo "Running the web server for API..."
../web/api.py &
sleep 3
echo

echo "Trying to add a subscriber..."
curl -H "Content-type: application/json" -X PUT -d '{
                                                        "projectName": "test",
                                                        "emailAddress": "osman@spam.bo",
                                                        "properties": {
                                                            "eyeColor": "brown",
                                                            "gender": "male"
                                                        }
                                                    }' http://localhost:8080/subscriber
echo
echo

echo "Trying to add a subscriber with invalid fields..."
curl -H "Content-type: application/json" -X PUT -d '{
                                                        "projectName": "test",
                                                        "emailAddress": "osman@spam.bo",
                                                        "gender": "male"
                                                    }' http://localhost:8080/subscriber
echo
echo

echo "Trying an address that does not exists..."
curl -H "Content-type: application/json" http://localhost:8080/doesNotExists
echo
echo

echo "Killing the web server..."
trap "kill 0" SIGINT SIGTERM EXIT
