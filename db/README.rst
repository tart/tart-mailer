Numbering
---------

Script names start with numbers to make them ordered.

There are more than one script with number 000. They are functions and operators which have no dependency to
the project. Some of them are copied from other sources for convenience.

Statistics Views
----------------

Statistics views are slow. Change them as materaliazed views on the script 019-emailStatistics.sql. Add a cron
to refresh them [1].

[1] http://www.postgresql.org/docs/current/static/sql-refreshmaterializedview.html
