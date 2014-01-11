Begin;

Create or replace function EmailToSendCount()
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend where status = 'waiting'
$$;

Create or replace function FormatEmailToSend(body text, k text[], v text[])
    returns text
    language plpythonu
    as $$
return body.format(**dict(zip(k, v)))
$$;

Create or replace function NextEmailToSend()
    returns table (
        toName varchar(200),
        toAddress varchar(200),
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text
    )
    language sql
    as $$
With FirstWaitingEmail as (select * from EmailSend
            where status = 'waiting'
            order by emailId, subscriberId
            limit 1
            for update),
    UpdatedEmailSend as (update EmailSend
            set status = 'sent'
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Subscriber.fullName as toName,
            Subscriber.emailAddress as toAddress,
            Email.fromName,
            Email.fromAddress,
            FormatEmailToSend(Email.subject, Formatter.k, Formatter.v) as subject,
            FormatEmailToSend(Email.plainBody, Formatter.k, Formatter.v) as plainBody,
            FormatEmailToSend(Email.hTMLBody, Formatter.k, Formatter.v) as hTMLBody
        from UpdatedEmailSend
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
            join Email on UpdatedEmailSend.emailId = Email.id
                cross join lateral (select array_agg(key) as k, array_agg(value) as v
                    from ((select * from each(Subscriber.properties))
                        union values ('fullname', Subscriber.fullName),
                                ('unsubscribeurl',
                                    Email.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend)),
                                ('redirecturl',
                                    Email.returnURLRoot || 'subscriber/' || EmailHash(UpdatedEmailSend)),
                                ('trackerimageurl',
                                    Email.returnURLRoot || 'trackerImage/' ||
                                                EmailHash(UpdatedEmailSend))) as A) as Formatter
$$;

Commit;

