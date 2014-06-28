Create or replace function NewEmailSendFeedback(
        messageHash text,
        state EmailState,
        iPAddress inet
    ) returns boolean
    language sql
    as $$
With NewEmailSendFeedback as (insert into EmailSendFeedback (fromAddress, toAddress, emailId, state, iPAddress)
    select fromAddress, toAddress, emailId, NewEmailSendFeedback.state, NewEmailSendFeedback.iPAddress
        from EmailSend
            where EmailSend.state >= 'sent'
                    and MessageHash(EmailSend) = NewEmailSendFeedback.messageHash
                    and not exists (select 1 from EmailSendFeedback
                                where EmailSendFeedback.fromAddress = EmailSend.fromAddress
                                        and EmailSendFeedback.toAddress = EmailSend.toAddress
                                        and EmailSendFeedback.state = NewEmailSendFeedback.state)
    returning *)
    select exists (select 1 from NewEmailSendFeedback)
$$;

Create or replace function EmailSendRedirectURL(text)
    returns varchar(1000)
    language sql strict
    as $$
Select Email.redirectURL
    from EmailSend
        join Email using (fromAddress, emailId)
        where MessageHash(EmailSend) = $1
$$;
