Begin;

Create or replace function UpdateEmailSend (
        emailHash text,
        newStatus EmailSendStatus,
        iPAddress inet default null
    ) returns EmailSend
    language sql
    as $$
With NewEmailSendFeedback as (insert into EmailSendFeedback (emailId, subscriberId, status, iPAddress)
            select emailId, subscriberId, newStatus, iPAddress
                from EmailSend
                    where EmailHash(EmailSend) = emailHash
                            and not exists (select 1 from EmailSendFeedback
                                        where EmailSendFeedback.emailId = EmailSend.emailId
                                                and EmailSendFeedback.subscriberId = EmailSend.subscriberId
                                                and EmailSendFeedback.status = newStatus)
            returning *)
    update EmailSend
        set status = newStatus
        from NewEmailSendFeedback
            where EmailSend.emailId = NewEmailSendFeedback.emailId
                    and EmailSend.subscriberId = NewEmailSendFeedback.subscriberId
                    and EmailSend.status < newStatus
        returning EmailSend.*
$$;

Create or replace function UnsubscribeEmailSend (
        emailHash text,
        iPAddress inet
    ) returns boolean
    language sql
    as $$
With UpdatedSubscriber as (update Subscriber
            set status = 'unsubscribed'
            from UpdateEmailSend(emailHash, 'unsubscribed', iPAddress) as EmailSend
                where EmailSend.subscriberId = Subscriber.id
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
    from UpdateEmailSend(emailHash, 'redirected', iPAddress) as EmailSend
        join Email on EmailSend.emailId = Email.id
$$;

Commit;

