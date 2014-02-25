#!/bin/bash -e

export PGDATABASE=mailertest

echo "Trying to send an email..."
../worker/send.py --project test --amount 1 --timeout 10 --debug
echo
