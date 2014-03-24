Begin;

Create or replace function SendTestEmail(
        fromAddress varchar(200),
        toAddress varchar(200),
        emailId integer,
        variationId integer
    ) returns boolean
    language sql
    as $$
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

Create or replace function SendBulkEmail(
        fromAddress varchar(200),
        emailId integer,
        subscriberCount integer,
        locale text[],
        variationId text[]
    ) returns bigint
    language sql
    as $$
With BulkEmail as (select *
        from Email
            where fromAddress = SendBulkEmail.fromAddress
                    and emailId = SendBulkEmail.emailId
                    and bulk),
    SubscriberWithRowNumber as (select *, row_number() over () as rowNumber
        from Subscriber
            where fromAddress = SendBulkEmail.fromAddress
                    and exists (select 1 from unnest(SendBulkEmail.locale) as locale
                                where locale is not distinct from Subscriber.locale)
                    and not exists (select 1 from EmailSend
                                where EmailSend.fromAddress = SendBulkEmail.fromAddress
                                        and EmailSend.toAddress = Subscriber.toAddress
                                        and EmailSend.emailId = SendBulkEmail.emailId)
                    and not exists (select 1 from EmailSendFeedback
                                where EmailSendFeedback.fromAddress = SendBulkEmail.fromAddress
                                        and EmailSendFeedback.toAddress = Subscriber.toAddress
                                        and EmailSendFeedback.feedbackType = 'unsubscribe')
                    and not exists (select 1 from EmailSendResponseReport
                                where EmailSendResponseReport.fromAddress = SendBulkEmail.fromAddress
                                        and EmailSendResponseReport.toAddress = Subscriber.toAddress)
            limit SendBulkEmail.subscriberCount),
    EmailVariationWithRowNumber as (select EmailVariation.*,
            row_number() over () as rowNumber,
            count(*) over () as count
        from BulkEmail
            join EmailVariation using (fromAddress, emailId)
            where EmailVariation.variationId = any(SendBulkEmail.variationId::smallint[])),
    NewEmailSend as (insert into EmailSend (fromAddress, toAddress, emailId, variationId)
        select SendBulkEmail.fromAddress, S.toAddress, SendBulkEmail.emailId, E.variationId
            from SubscriberWithRowNumber as S
                join EmailVariationWithRowNumber as E on (S.rowNumber - 1) % E.count = E.rowNumber - 1
        returning *),
    EmailVariationStats as (select fromAddress, emailId, variationId, count(*) as send
        from NewEmailSend
            group by fromAddress, emailId, variationId),
    UpdatedEmailVariation as (update EmailVariation
        set draft = false
        from EmailVariationStats
            where EmailVariation.fromAddress = EmailVariationStats.fromAddress
                    and EmailVariation.emailId = EmailVariationStats.emailId
                    and EmailVariation.variationId = EmailVariationStats.variationId
        returning *)
    select sum(send)::bigint as send from UpdatedEmailVariation
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

Commit;
