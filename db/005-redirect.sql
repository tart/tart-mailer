Create or replace function EmailSendRedirect (
        emailHash text
    ) returns varchar(1000)
    language sql
    as $$
With UpdatedEmailSend as (Update EmailSend
            set status = 'redirected'
            where EmailHash(EmailSend) = emailHash
                    and status < 'redirected'
            returning *),
    NewEmailSendLog as (insert into EmailSendLog (emailId, subscriberId, status, affected)
            select emailId, subscriberId, 'redirected', exists(select * from UpdatedEmailSend)
                from EmailSend
                    where EmailHash(EmailSend) = emailHash
            returning *)
    select Email.redirectURL from NewEmailSendLog join Email on NewEmailSendLog.emailId = Email.id
$$;

