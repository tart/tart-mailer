Create or replace function NewEmailSendFeedback(
        emailHash text,
        feedbackType EmailSendFeedbackType,
        iPAddress inet
    ) returns boolean
    language sql
    as $$
With NewEmailSendFeedback as (insert into EmailSendFeedback (fromAddress, toAddress, emailId, feedbackType, iPAddress)
    select fromAddress, toAddress, emailId, NewEmailSendFeedback.feedbackType, NewEmailSendFeedback.iPAddress
        from EmailSend
            where sent
                    and EmailHash(EmailSend) = NewEmailSendFeedback.emailHash
                    and not exists (select 1 from EmailSendFeedback
                                where EmailSendFeedback.fromAddress = EmailSend.fromAddress
                                        and EmailSendFeedback.toAddress = EmailSend.toAddress
                                        and EmailSendFeedback.feedbackType = NewEmailSendFeedback.feedbackType)
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
        where EmailHash(EmailSend) = $1
$$;
