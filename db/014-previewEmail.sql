Create or replace function PreviewEmailURL(integer)
    returns text
    language sql
    as $$
Select Email.returnURLRoot || 'view/' || EmailHash(EmailSend)
    from Email
        join EmailSend on EmailSend.emailId = Email.id
            left join EmailSendFeedback on EmailSendFeedback.emailId = EmailSend.emailId
                    and EmailSendFeedback.subscriberId = EmailSend.subscriberId
                    and EmailSendFeedback.type = 'view'
        where Email.id = $1
        group by Email.id, EmailSend
        order by count(EmailSendFeedback) + random() desc
        limit 1
$$;

