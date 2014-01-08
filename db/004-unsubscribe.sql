Create or replace function EmailSendUnsubscribe (
        unsubscribeHash text
    ) returns boolean
    language sql
    as $$
With UbsubscribedEmailSend as (Update EmailSend
            set status = 'unsubscribed'
            where UnsubscribeHash(EmailSend) = unsubscribeHash
            returning *),
    NewEmailSendLog as (insert into EmailSendLog (emailId, subscriberId, status)
            select emailId, subscriberId, status
                from UbsubscribedEmailSend
            returning *),
    UpdatedSubscriber as (update Subscriber
            set status = 'unsubscribed'
            from NewEmailSendLog
                where NewEmailSendLog.subscriberId = Subscriber.id
                        and Subscriber.status < 'unsubscribed'
            returning *)
    select exists(select * from UpdatedSubscriber)
$$;

