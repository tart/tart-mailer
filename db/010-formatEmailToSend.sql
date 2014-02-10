Begin;

Create extension if not exists plpythonu;

Create or replace function FormatEmailToSend(body text, k text[], v text[])
    returns text
    language plpythonu strict
    as $$
# Default string.format() function cannot be use is does not support default values.
# See http://bugs.python.org/issue6081

from string import Formatter
from collections import defaultdict

return Formatter().vformat(body, (), defaultdict(str, zip(k, v)))
$$;

Create or replace function FormatEmailToSend(
        body text,
        subscriberProperties hstore,
        returnURLRoot varchar(1000),
        emailHash text
    ) returns text
    language sql strict
    as $$
With Formatter as (select * from each(subscriberProperties)
        union values ('unsubscribeurl', returnURLRoot || 'unsubscribe/' || emailHash),
                ('redirecturl', returnURLRoot || 'redirect/' || emailHash),
                ('trackerimageurl', returnURLRoot || 'trackerImage/' || emailHash),
                ('viewurl', returnURLRoot || 'view/' || emailHash))
    select FormatEmailToSend($1, array_agg(key), array_agg(value))
        from Formatter
$$;

Commit;
