#!/bin/bash -e

echo "Trying to send an email..."
../worker/send.py --sender tart-mailer@github.com --timeout 10 --debug
echo
