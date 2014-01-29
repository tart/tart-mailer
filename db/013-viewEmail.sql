Alter type EmailSendFeedbackType add value 'view' after 'trackerImage';

Begin;

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

Create or replace function NextEmailToSend(varchar(200))
    returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text
    )
    language sql strict
    as $$
With FirstWaitingEmail as (select EmailSend.*
            from Email
                join EmailSend on EmailSend.emailId = Email.id
                        and not sent
                where Email.outgoingServerName = $1
                order by Email.draft desc, Email.id, EmailSend.subscriberId
            limit 1
            for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Email.fromName,
            Email.fromAddress,
            Subscriber.emailAddress,
            FormatEmailToSend(Email.subject, Subscriber.properties, Email.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(Email.plainBody, Subscriber.properties, Email.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(Email.hTMLBody, Subscriber.properties, Email.returnURLRoot, EmailHash(UpdatedEmailSend)),
            Email.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend)
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
$$;

Create or replace function ViewEmailBody(text)
    returns text
    language sql strict
    as $$
Select coalesce(FormatEmailToSend(Email.hTMLBody, Subscriber.properties, Email.returnURLRoot, $1),
                FormatEmailToSend(Email.plainBody, Subscriber.properties, Email.returnURLRoot, $1))
    from EmailSend
        join Email on EmailSend.emailId = Email.id
        join Subscriber on EmailSend.subscriberId = Subscriber.id
        where EmailHash(EmailSend) = $1
$$;

Commit;

