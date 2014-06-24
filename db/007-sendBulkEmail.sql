Create index SubscriberSendBulkEmailI on Subscriber (fromAddress, locale, state, revisedAt);

Create or replace function SendBulkEmail(
        fromAddress varchar(200),
        emailId integer,
        maxSubscriber integer,
        variationId text[],
        properties hstore
    ) returns bigint
    language sql
    as $$
With NewEmailSend as (insert into EmailSend (fromAddress, toAddress, emailId, variationId)
        select Subscriber.fromAddress,
                Subscriber.toAddress,
                EmailVariation.emailId,
                first(EmailVariation.variationId order by random())
            from Email
                join Subscriber using (fromAddress)
                    left join EmailSend using (fromAddress, toAddress, emailId)
                join EmailVariation using (fromAddress, emailId)
                where Email.fromAddress = SendBulkEmail.fromAddress
                        and Email.emailId = SendBulkEmail.emailId
                        and Email.bulk
                        and EmailVariation.variationId = any(SendBulkEmail.variationId::smallint[])
                        and Subscriber.locale = any (Email.locale)
                        and Subscriber.properties @> SendBulkEmail.properties
                        and Subscriber.state in ('new', 'sent', 'trackerImage', 'view', 'redirect')
                        and EmailSend.fromAddress is null
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
