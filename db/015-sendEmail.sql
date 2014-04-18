Create extension if not exists hstore;

Create or replace function SendToSubscriber(
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        redirectURL varchar(1000) default null,
        plainBody varchar(1000) default null,
        hTMLBody varchar(1000) default null
    ) returns setof EmailSend
    language sql
    as $$
With InsertedEmail as (insert into Email (fromAddress, redirectURL)
            select fromAddress, redirectURL
                from Subscriber
                    where fromAddress = SendToSubscriber.fromAddress
                            and toAddress = SendToSubscriber.toAddress
                            and not exists (select 1 from EmailSendFeedback
                                        where EmailSendFeedback.fromAddress = Subscriber.fromAddress
                                                and EmailSendFeedback.toAddress = Subscriber.toAddress
                                                and EmailSendFeedback.feedbackType = 'unsubscribe')
                            and not exists (select 1 from EmailSendResponseReport
                                        where EmailSendResponseReport.toAddress = Subscriber.toAddress)
            returning *),
        InsertedEmailVariation as (insert into EmailVariation (fromAddress, emailId, subject, plainBody, hTMLBody)
            select fromAddress, emailId, subject, plainBody, hTMLBody
                from InsertedEmail
            returning *)
    insert into EmailSend (fromAddress, toAddress, emailId, variationId)
            select fromAddress, toAddress, emailId, variationId
                from InsertedEmailVariation
            returning *
$$;

Create or replace function SendBulkEmail(
        fromAddress varchar(200),
        emailId integer,
        subscriberCount integer,
        variationId text[],
        locale text[],
        properties hstore
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
                    and properties @> SendBulkEmail.properties
                    and exists (select 1 from unnest(SendBulkEmail.locale) as locale
                                where locale is not distinct from Subscriber.locale)
                    and not exists (select 1 from EmailSend
                                where EmailSend.fromAddress = Subscriber.fromAddress
                                        and EmailSend.toAddress = Subscriber.toAddress
                                        and EmailSend.emailId = SendBulkEmail.emailId)
                    and not exists (select 1 from EmailSendFeedback
                                where EmailSendFeedback.fromAddress = Subscriber.fromAddress
                                        and EmailSendFeedback.toAddress = Subscriber.toAddress
                                        and EmailSendFeedback.feedbackType = 'unsubscribe')
                    and not exists (select 1 from EmailSendResponseReport
                                where EmailSendResponseReport.toAddress = Subscriber.toAddress)
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
