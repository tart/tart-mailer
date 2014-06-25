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

Create index EmailSendQueueI on EmailSend (toAddress) where not sent;

Create or replace function NextEmailToSend(
        messageFrame int default 1,
        fromAddress varchar(200) default null
    ) returns table (
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
With FirstWaitingEmail as (select EmailSend.fromAddress,
                EmailSend.toAddress,
                EmailSend.emailId,
                EmailVariation.variationId,
                EmailVariation.subject,
                EmailVariation.plainBody,
                EmailVariation.hTMLBody,
                Email.bulk
            from EmailSend
                join EmailVariation using (fromAddress, emailId)
                join Email using (fromAddress)
                where not EmailSend.sent
                        and Email.state = 'send'
                        and EmailVariation.state = 'send'
                        and (NextEmailToSend.fromAddress is null
                                or EmailSend.fromAddress = NextEmailToSend.fromAddress)
                order by EmailSend.toAddress
                    limit 1
                    offset random() * NextEmailToSend.messageFrame),
    EmailToSend as (update EmailSend
            set sent = true,
                    variationId = FirstWaitingEmail.variationId
            from FirstWaitingEmail
                where EmailSend.fromAddress = FirstWaitingEmail.fromAddress
                        and EmailSend.toAddress = FirstWaitingEmail.toAddress
                        and EmailSend.emailId = FirstWaitingEmail.emailId
            returning FirstWaitingEmail.*,
                    EmailSend)
    select Sender.fromName,
            Sender.fromAddress,
            Subscriber.toAddress,
            FormatEmailToSend(EmailToSend.subject, Subscriber.properties),
            FormatEmailToSend(EmailToSend.plainBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend.EmailSend)),
            FormatEmailToSend(EmailToSend.hTMLBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend.EmailSend)),
            Sender.returnURLRoot || 'unsubscribe/' || MessageHash(EmailToSend.EmailSend),
            EmailToSend.bulk
        from EmailToSend
            join Sender using (fromAddress)
            join Subscriber using (fromAddress, toAddress)
$$;

Create or replace function EmailToSendCount()
    returns bigint
    language sql
    as $$
Select count(*)
    from EmailSend
        join Email using (fromAddress)
        where not EmailSend.sent
                and Email.state = 'send'
                and (EmailSend.fromAddress, EmailSend.emailId) in (select fromAddress, emailId
                            from EmailVariation
                                where state = 'send')
$$;

Create or replace function EmailToSendCount(fromAddress varchar(200))
    returns bigint
    language sql
    as $$
Select count(*)
    from EmailSend
        join Email using (fromAddress)
        where not EmailSend.sent
                and EmailSend.fromAddress = EmailToSendCount.fromAddress
                and Email.state = 'send'
                and (EmailSend.fromAddress, EmailSend.emailId) in (select fromAddress, emailId
                            from EmailVariation
                                where state = 'send')
$$;
