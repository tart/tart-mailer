Create domain LocaleCodeArray char(5)[] collate "C" not null default array[]::char(5)[]
    constraint LocaleCodeArrayC check ('^[a-z]{2}_[A-Z]{2}$' ^~ all(value));

Alter table EmailVariation
    add column locale LocaleCodeArray;

Create index EmailVariationLocalesI on EmailVariation using gin (locale);

Create unique index EmailSendFeedbackUnsubscribe on EmailSendFeedback (fromAddress, toAddress)
    where feedbackType = 'unsubscribe';

Create or replace view EmailVariationSubscriberStatistics as
    with SubscriberUnsubscribed as (select fromAddress, toAddress from EmailSendFeedback
            where feedbackType = 'unsubscribe'),
        SubscriberWithResponseReport as (select distinct fromAddress, toAddress from EmailSendResponseReport)
        select EmailVariation.fromAddress,
                EmailVariation.emailId,
                EmailVariation.variationId,
                EmailVariation.locale,
                coalesce(count(EmailSend), 0) as send
            from EmailVariation
                left join EmailSend using (fromAddress, emailId, variationId)
                group by 1, 2, 3
                order by 1, 2, 3;

Create or replace function SendBulkEmail(
        fromAddress varchar(200),
        emailId integer,
        maxSubscriber integer,
        variationId text[],
        properties hstore
    ) returns bigint
    language sql
    as $$
With SubscriberUnsubscribed as (select fromAddress, toAddress from EmailSendFeedback
            where feedbackType = 'unsubscribe'),
    SubscriberWithResponseReport as (select distinct fromAddress, toAddress from EmailSendResponseReport),
    NewEmailSend as (insert into EmailSend (fromAddress, toAddress, emailId, variationId)
        select Subscriber.fromAddress,
                Subscriber.toAddress,
                EmailVariation.emailId,
                first(EmailVariation.variationId order by random())
            from Email
                join Subscriber using (fromAddress)
                    left join SubscriberUnsubscribed using (fromAddress, toAddress)
                    left join SubscriberWithResponseReport using (fromAddress, toAddress)
                    left join EmailSend using (fromAddress, toAddress, emailId)
                join EmailVariation using (fromAddress, emailId)
                where Email.fromAddress = SendBulkEmail.fromAddress
                        and Email.emailId = SendBulkEmail.emailId
                        and Email.bulk
                        and EmailVariation.variationId = any(SendBulkEmail.variationId::smallint[])
                        and (EmailVariation.locale = '{}'
                                or exists (select 1 from unnest(EmailVariation.locale) as locale
                                            where locale is not distinct from Subscriber.locale))
                        and Subscriber.properties @> SendBulkEmail.properties
                        and SubscriberUnsubscribed is null
                        and SubscriberWithResponseReport is null
                        and EmailSend is null
                group by Subscriber.fromAddress, Subscriber.toAddress, EmailVariation.emailId
                order by Subscriber.revisedAt
                limit SendBulkEmail.maxSubscriber
            returning EmailSend.*),
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
