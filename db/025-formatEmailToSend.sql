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
        returnURLRoot varchar(1000) default null,
        emailHash text default null
    ) returns text
    language sql
    as $$
With Formatter as (select * from each(subscriberProperties)
        union select * from (values ('unsubscribeurl', returnURLRoot || 'unsubscribe/' || emailHash),
                        ('redirecturl', returnURLRoot || 'redirect/' || emailHash),
                        ('trackerimageurl', returnURLRoot || 'trackerImage/' || emailHash),
                        ('viewurl', returnURLRoot || 'view/' || emailHash)) as UrlVariable
                where returnURLRoot is not null and emailHash is not null)
    select FormatEmailToSend($1, array_agg(key), array_agg(value))
        from Formatter
$$;

Drop function if exists NextEmailToSend(varchar(200));

Create or replace function NextEmailToSend(varchar(200))
    returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text,
        bulk boolean
    )
    language sql strict
    as $$
With FirstWaitingEmail as (select EmailSend.*
            from Email
                join EmailSend on EmailSend.emailId = Email.id
                        and not sent
                where Email.outgoingServerName = $1
                order by Email.id, EmailSend.subscriberId
            limit 1
            for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Project.fromName,
            Project.emailAddress,
            Subscriber.emailAddress,
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            Project.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend),
            Email.bulk
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
                join Project on Email.projectName = Project.name
            join EmailVariation on UpdatedEmailSend.emailId = EmailVariation.emailId
                    and UpdatedEmailSend.variationRank = EmailVariation.rank
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
$$;

Create or replace function ViewEmailBody(text)
    returns text
    language sql strict
    as $$
Select coalesce(FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Project.returnURLRoot, $1),
                FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Project.returnURLRoot, $1))
    from EmailSend
        join Email on EmailSend.emailId = Email.id
            join Project on Email.projectName = Project.name
        join EmailVariation on EmailSend.emailId = EmailVariation.emailId
                and EmailSend.variationRank = EmailVariation.rank
        join Subscriber on EmailSend.subscriberId = Subscriber.id
        where EmailHash(EmailSend) = $1
$$;

Commit;
