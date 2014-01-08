Create or replace function EmailSendUnsubscribe (
        emailHash text
    ) returns boolean
    language sql
    as $$
With UpdatedEmailSend as (update EmailSend
            set status = 'unsubscribed'
            where EmailHash(EmailSend) = emailHash
                    and status < 'unsubscribed'
            returning *),
    NewEmailSendLog as (insert into EmailSendLog (emailId, subscriberId, status, affected)
            select emailId, subscriberId, 'unsubscribed', exists(select * from UpdatedEmailSend)
                from EmailSend
                    where EmailHash(EmailSend) = emailHash
            returning *),
    UpdatedSubscriber as (update Subscriber
            set status = 'unsubscribed'
            from NewEmailSendLog
                where NewEmailSendLog.subscriberId = Subscriber.id
                        and Subscriber.status < 'unsubscribed'
            returning *)
    select exists(select * from UpdatedSubscriber)
$$;

