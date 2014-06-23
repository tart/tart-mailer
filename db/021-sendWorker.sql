Create or replace function RemoveNotAllowedEmailSend()
    returns setof EmailSend
    language sql strict
    as $$
Delete from EmailSend
    where not sent
            and (fromAddress, toAddress) in (select fromAddress, toAddress
                        from Subscriber
                            where state in ('responseReport', 'unsubscribe'))
    returning *
$$;

Create or replace function RemoveNotAllowedEmailSend(fromAddress varchar(200))
    returns setof EmailSend
    language sql strict
    as $$
Delete from EmailSend
    where not sent
            and fromAddress = RemoveNotAllowedEmailSend.fromAddress
            and (fromAddress, toAddress) in (select fromAddress, toAddress
                        from Subscriber
                            where state in ('responseReport', 'unsubscribe'))
    returning *
$$;

Create index EmailSendQueueI on EmailSend (fromAddress) where not sent;

Create or replace function NextEmailToSend(fromAddress varchar(200) default null)
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
    language sql
    as $$
With FirstWaitingEmail as (select EmailSend.*
        from EmailSend
            where not sent
                    and (NextEmailToSend.fromAddress is null or fromAddress = NextEmailToSend.fromAddress)
        order by random()
            limit 1
        for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Sender.fromName,
            Sender.fromAddress,
            Subscriber.toAddress,
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(UpdatedEmailSend)),
            Sender.returnURLRoot || 'unsubscribe/' || MessageHash(UpdatedEmailSend),
            Email.bulk
        from UpdatedEmailSend
            join Sender using (fromAddress)
            join Email using (fromAddress, emailId)
            join EmailVariation using (fromAddress, emailId, variationId)
            join Subscriber using (fromAddress, toAddress)
$$;

Create or replace function EmailToSendCount()
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend where not sent
$$;

Create or replace function EmailToSendCount(fromAddress varchar(200))
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend where not sent and fromAddress = EmailToSendCount.fromAddress
$$;
