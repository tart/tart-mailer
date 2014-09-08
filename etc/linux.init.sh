#!/bin/bash -e

# Tart-Mailer
#
# chkconfig: - 85 15
# description: An application to maintain a mailing list, send bulk mails.
# processname: uwsgi


PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

case "$1" in
    start)
        echo -n "Starting Tart-Mailer: "

        if [ -f /var/run/mailer.pid ]; then
            echo "pid file /var/run/mailer.pid exists"
            exit 1
        fi

        uwsgi --pidfile /var/run/mailer.pid --ini /etc/mailer/uwsgi.ini &

        echo "OK"
    ;;

    stop)
        echo -n "Stopping Tart-Mailer: "

        if [ ! -f /var/run/mailer.pid ]; then
            echo "pid file /var/run/mailer.pid does not exists"
            exit 1
        fi

        kill -s 3 $(cat /var/run/mailer.pid)

        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        fi

        rm -f /var/run/mailer.pid

        echo "OK"
    ;;

    reload)
        echo -n "Reloading Tart-Mailer: "

        if [ ! -f /var/run/mailer.pid ]; then
            echo "pid file /var/run/mailer.pid does not exists"
            exit 1
        fi

        kill -s 1 $(cat /var/run/mailer.pid)

        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        fi

        echo "OK"
    ;;

    force-reload)
        echo -n "Reloading Tart-Mailer: "

        if [ ! -f /var/run/mailer.pid ]; then
            echo "pid file /var/run/mailer.pid does not exists"
            exit 1
        fi

        kill -s 15 $(cat /var/run/mailer.pid)

        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        fi

        echo "OK"
    ;;

    restart)
        $0 stop
        sleep 2
        $0 start
    ;;

    status)  
        echo -n "Checking Tart-Mailer: "

        if [ ! -f /var/run/mailer.pid ]; then
            echo "pid file /var/run/mailer.pid does not exists"
            exit 1
        fi

        kill -s 10 $(cat /var/run/mailer.pid)

        if [ $? -gt 0 ]; then
            echo "was not running" 
            exit 1
        fi

        echo "OK"
    ;;

    *)  
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status}" >&2
        exit 1
    ;;
esac

exit 0
