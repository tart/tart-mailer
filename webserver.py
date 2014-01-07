#!/usr/bin/env python3.3
##
# Tart Mailer
#
# Copyright (c) 2013, Tart İnternet Teknolojileri Ticaret AŞ
#
# Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby
# granted, provided that the above copyright notice and this permission notice appear in all copies.
#
# The software is provided "as is" and the author disclaims all warranties with regard to the software including all
# implied warranties of merchantability and fitness. In no event shall the author be liable for any special, direct,
# indirect, or consequential damages or any damages whatsoever resulting from loss of use, data or profits, whether
# in an action of contract, negligence or other tortious action, arising out of or in connection with the use or
# performance of this software.
##

from flask import Flask, request, render_template
from libtart.postgres import Postgres

app = Flask(__name__)
postgres = Postgres(database='mailer')

@app.route('/newEmail', methods=['GET', 'POST'])
def newEmail():
    message = ''

    if request.method == 'POST':
        newEmail = postgres.callOneLine('NewEmail', **dict(request.form.items()))
        message = str(newEmail['subscribercount']) + ' email added to the queue.'

    subscriberInfo = postgres.callOneLine('SubscriberInfo')
    return render_template('newEmail.html', message=message, **subscriberInfo) 


if __name__ == '__main__':
    app.run(debug=True)

