Create unique index EmailSendQueueI on EmailSend (sendOrder) where state = 'new';

Create or replace function CancelNotAllowedEmailSend(fromAddress varchar(200) default null)
    returns setof EmailSend
    language sql
    as $$
Update EmailSend
    set state = 'cancelled'
    where state = 'new'
            and ((fromAddress, toAddress) in (select fromAddress, toAddress
                        from Subscriber
                            where state in ('cancelled', 'responseReported', 'unsubscribed'))
                    or (fromAddress, emailId) in (select fromAddress, emailId
                                from Email
                                    where state = 'cancelled')
                    or (fromAddress, emailId) in (select fromAddress, emailId
                                from EmailVariation
                                    group by fromAddress, emailId
                                        having 'cancelled' = all (array_agg(state))))
    returning *
$$;

Create or replace function EmailToSendCount(fromAddress varchar(200) default null)
    returns bigint
    language sql
    as $$
Select count(*)
    from EmailSend
        join Email using (fromAddress, emailId)
        where EmailSend.state = 'new'
                and (EmailToSendCount.fromAddress is null
                        or EmailSend.fromAddress = EmailToSendCount.fromAddress)
                and Email.state = 'sent'
                and (EmailSend.fromAddress, EmailSend.emailId) in (select fromAddress, emailId
                            from EmailVariation
                                where state = 'sent')
$$;

Create or replace function NextEmailToSend(
        fromAddress varchar(200) default null,
        sendOffset integer default 0
    ) returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        returnPath varchar(200),
        replyTo varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text,
        bulk boolean,
        sendOrder integer
    )
    language sql
    as $$
With FirstWaitingEmailSend as (select EmailSend.sendOrder,
                first(EmailVariation.variationId order by random()) as variationId
            from EmailSend
                join Subscriber using (fromAddress, toAddress)
                join Email using (fromAddress, emailId)
                join EmailVariation using (fromAddress, emailId)
                where EmailSend.state = 'new'
                        and Subscriber.state in ('new', 'sent', 'tracked', 'viewed', 'redirected')
                        and Email.state = 'sent'
                        and EmailVariation.state = 'sent'
                        and (NextEmailToSend.fromAddress is null
                                or EmailSend.fromAddress = NextEmailToSend.fromAddress)
                        and (EmailSend.variationId is null
                                or EmailVariation.variationId = EmailSend.variationId)
                group by EmailSend.sendOrder
                order by EmailSend.sendOrder
                    limit 1
                    offset NextEmailToSend.sendOffset),
    EmailToSend as (update EmailSend
            set state = 'sent',
                    sentAt = now(),
                    variationId = FirstWaitingEmailSend.variationId
            from FirstWaitingEmailSend
                where EmailSend.state = 'new'
                        and EmailSend.sendOrder = FirstWaitingEmailSend.sendOrder
            returning EmailSend.*)
    select Sender.fromName,
            Sender.fromAddress,
            Sender.returnPath,
            Sender.replyTo,
            Subscriber.toAddress,
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend)),
            Sender.returnURLRoot || 'unsubscribe/' || MessageHash(EmailToSend),
            Email.bulk,
            EmailToSend.sendOrder
        from EmailToSend
            join Sender using (fromAddress)
            join Subscriber using (fromAddress, toAddress)
            join Email using (fromAddress, emailId)
            join EmailVariation using (fromAddress, emailId, variationId)
$$;
