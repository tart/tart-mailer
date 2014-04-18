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
