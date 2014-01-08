Begin;

Create or replace function UpdateEmailSend (
        emailHash text,
        iPAddress inet,
        newStatus EmailSendStatus
    ) returns EmailSendLog
    language sql
    as $$
With UpdatedEmailSend as (Update EmailSend
            set status = newStatus
            where EmailHash(EmailSend) = emailHash
                    and status < newStatus
            returning *)
    insert into EmailSendLog (emailId, subscriberId, iPAddress, status, affected)
        select emailId, subscriberId, iPAddress, newStatus, exists(select * from UpdatedEmailSend)
            from EmailSend
                where EmailHash(EmailSend) = emailHash
        returning *
$$;

Create or replace function UnsubscribeEmailSend (
        emailHash text,
        iPAddress inet
    ) returns boolean
    language sql
    as $$
With UpdatedSubscriber as (update Subscriber
            set status = 'unsubscribed'
            from UpdateEmailSend(emailHash, iPAddress, 'unsubscribed') as NewEmailSendLog
                where NewEmailSendLog.subscriberId = Subscriber.id
                        and Subscriber.status < 'unsubscribed'
            returning *)
    select exists(select * from UpdatedSubscriber)
$$;

Create or replace function RedirectEmailSend (
        emailHash text,
        iPAddress inet
    ) returns varchar(1000)
    language sql
    as $$
select Email.redirectURL
    from UpdateEmailSend(emailHash, iPAddress, 'redirected') as NewEmailSendLog
        join Email on NewEmailSendLog.emailId = Email.id
$$;

Commit;
