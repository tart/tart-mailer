Create index SubscriberSendBulkEmailI on Subscriber (fromAddress, locale, state, revisedAt);

Create or replace function SendBulkEmail(
        fromAddress varchar(200),
        emailId integer,
        maxSubscriber integer,
        properties hstore
    ) returns bigint
    language sql
    as $$
With NewEmailSend as (insert into EmailSend (fromAddress, toAddress, emailId)
        select Email.fromAddress,
                Subscriber.toAddress,
                Email.emailId
            from Email
                join Subscriber using (fromAddress)
                    left join EmailSend using (fromAddress, toAddress, emailId)
                where Email.fromAddress = SendBulkEmail.fromAddress
                        and Email.emailId = SendBulkEmail.emailId
                        and Email.bulk
                        and Email.state = 'sent'
                        and Subscriber.locale = any (Email.locale)
                        and Subscriber.properties @> SendBulkEmail.properties
                        and Subscriber.state in ('new', 'sent', 'trackerImage', 'view', 'redirect')
                        and EmailSend.fromAddress is null
                order by Subscriber.revisedAt
                    limit SendBulkEmail.maxSubscriber
            returning EmailSend.*)
    select count(*) as send from NewEmailSend
$$;
