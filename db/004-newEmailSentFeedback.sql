Begin;

Create or replace function NewEmailSendFeedback (
        emailHash text,
        newType EmailSendFeedbackType,
        iPAddress inet
    ) returns boolean
    language sql
    as $$
With NewEmailSendFeedback as (insert into EmailSendFeedback (emailId, subscriberId, type, iPAddress)
            select emailId, subscriberId, newType, iPAddress
                from EmailSend
                    where EmailHash(EmailSend) = emailHash
                            and not exists (select 1 from EmailSendFeedback
                                        where EmailSendFeedback.emailId = EmailSend.emailId
                                                and EmailSendFeedback.subscriberId = EmailSend.subscriberId
                                                and EmailSendFeedback.type = newType)
            returning *)
    select exists (select 1 from NewEmailSendFeedback)
$$;

Create or replace function EmailSendRedirectURL (emailHash text)
    returns varchar(1000)
    language sql strict
    as $$
Select Email.redirectURL
    from EmailSend
        join Email on EmailSend.emailId = Email.id
        where EmailHash(EmailSend) = emailHash
$$;

Commit;

