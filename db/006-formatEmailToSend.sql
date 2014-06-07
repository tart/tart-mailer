Create extension if not exists plpythonu;

Create or replace function FormatEmailToSend(body text, k text[], v text[])
    returns text
    language plpythonu strict
    as $$
# Default string.format() function cannot be used because it does not support default values.
# See http://bugs.python.org/issue6081

from string import Formatter
from collections import defaultdict

return Formatter().vformat(body, (), defaultdict(str, zip(k, v)))
$$;

Create or replace function FormatEmailToSend(
        body text,
        properties hstore,
        returnURLRoot varchar(1000) default null,
        messageHash text default null
    ) returns text
    language sql
    as $$
With Formatter as (select * from each(properties)
        union select * from (values ('unsubscribeurl', returnURLRoot || 'unsubscribe/' || messageHash),
                        ('redirecturl', returnURLRoot || 'redirect/' || messageHash),
                        ('trackerimageurl', returnURLRoot || 'trackerImage/' || messageHash),
                        ('viewurl', returnURLRoot || 'view/' || messageHash)) as URLVariable
                where returnURLRoot is not null and messageHash is not null)
    select coalesce((select FormatEmailToSend($1, array_agg(key), array_agg(value)) from Formatter), $1)
$$;

Create or replace function ViewEmailBody(messageHash text)
    returns text
    language sql strict
    as $$
Select coalesce(FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Sender.returnURLRoot, $1),
                FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Sender.returnURLRoot, $1))
    from EmailSend
        join Email using (fromAddress, emailId)
        join Sender using (fromAddress)
        join EmailVariation using (fromAddress, emailId, variationId)
        join Subscriber using (fromAddress, toAddress)
        where MessageHash(EmailSend) = ViewEmailBody.messageHash
$$;
