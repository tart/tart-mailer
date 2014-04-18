Create or replace function SendTestEmail(
        fromAddress varchar(200),
        toAddress varchar(200),
        emailId integer,
        variationId integer
    ) returns boolean
    language sql
    as $$
Insert into Subscriber (fromAddress, toAddress)
    select SendTestEmail.fromAddress, SendTestEmail.toAddress
        from Sender
            where Sender.fromAddress = SendTestEmail.fromAddress
                    and not exists (select 1 from Subscriber
                                    where Subscriber.fromAddress = SendTestEmail.fromAddress
                                            and Subscriber.toAddress = SendTestEmail.toAddress);

With UpdatedEmailSend as (update EmailSend
            set sent = false,
                    variationId = variationId
            where fromAddress = SendTestEmail.fromAddress
                    and toAddress = SendTestEmail.toAddress
                    and emailId = SendTestEmail.emailId
            returning true),
    InsertedEmailSend as (insert into EmailSend (fromAddress, toAddress, emailId, variationId)
            values (SendTestEmail.fromAddress, SendTestEmail.toAddress, SendTestEmail.emailId, SendTestEmail.variationId)
            returning true)
    select coalesce((select * from UpdatedEmailSend),
                    (select * from InsertedEmailSend))
$$;

Create function SubscriberLocaleStats(
        fromAddress varchar(200),
        emailId integer
    ) returns table (
        locale char(5),
        total bigint,
        send bigint
    )
    language sql
    as $$
With FilteredEmailSend as (select * from EmailSend
            where emailId = SubscriberLocaleStats.emailId),
    Unsubscribe as (select * from EmailSendFeedback
            where feedbackType = 'unsubscribe')
    select Subscriber.locale, coalesce(count(*), 0), coalesce(count(FilteredEmailSend), 0)
        from Subscriber
            left join FilteredEmailSend using (fromAddress, toAddress)
            left join Unsubscribe using (fromAddress, toAddress)
            left join EmailSendResponseReport using (fromAddress, toAddress)
            where Subscriber.fromAddress = SubscriberLocaleStats.fromAddress
                    and Unsubscribe is null
                    and EmailSendResponseReport is null
            group by Subscriber.locale
            order by Subscriber.locale
$$;

Create or replace function EmailVariationStats(
        fromAddress varchar(200),
        emailId integer
    ) returns table (
        variationId smallint,
        send bigint
    )
    language sql
    as $$
Select EmailVariation.variationId, coalesce(count(EmailSend), 0)
    from EmailVariation
        left join EmailSend using (fromAddress, emailId, variationId)
        where EmailVariation.fromAddress = EmailVariationStats.fromAddress
                and EmailVariation.emailId = EmailVariationStats.emailId
        group by EmailVariation.variationId
        order by EmailVariation.variationId
$$;

Create or replace function EmailVariationStats(integer)
    returns table (
        variationId smallint,
        send bigint
    )
    language sql
    as $$
Select EmailVariation.variationId, coalesce(count(EmailSend), 0)
    from EmailVariation
        left join EmailSend using (fromAddress, emailId, variationId)
        where EmailVariation.emailId = $1
        group by EmailVariation.variationId
        order by EmailVariation.variationId
$$;
