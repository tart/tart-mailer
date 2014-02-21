Begin;

Alter table EmailSendResponseReport add column body text;

Create or replace function NewEmailSendResponseReport(
        incomingServerName varchar(200),
        fields hstore,
        originalHeaders hstore,
        body text default null
    ) returns boolean
    language sql
    as $$
With OriginalEmailSend as (select EmailSend.*
            from EmailSend
                join Email on EmailSend.emailId = Email.id
                join EmailVariation on EmailSend.emailId = EmailVariation.emailId
                        and EmailSend.variationRank = EmailVariation.rank
                join Subscriber on EmailSend.subscriberID = Subscriber.id
                where EmailSend.sent
                        and Email.incomingServerName = NewEmailSendResponseReport.incomingServerName
                        and ((NewEmailSendResponseReport.originalHeaders -> 'Subject') is null
                                or FormatEmailToSend(EmailVariation.subject, Subscriber.properties) =
                                        (NewEmailSendResponseReport.originalHeaders -> 'Subject'))
                        and (Subscriber.emailAddress in (NewEmailSendResponseReport.fields -> 'Original-Recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'Original-Recipient', ';', 2)),
                                NewEmailSendResponseReport.fields -> 'Original-Rcpt-to',
                                NewEmailSendResponseReport.fields -> 'Final-Recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'Final-Recipient', ';', 2)),
                                NewEmailSendResponseReport.originalHeaders -> 'To')
                                or (NewEmailSendResponseReport.body like '%@%'
                                        and NewEmailSendResponseReport.body like '%' || Subscriber.emailAddress || '%')))
    insert into EmailSendResponseReport (emailId, subscriberId, fields, originalHeaders, body)
        select emailId, subscriberId,
                NewEmailSendResponseReport.fields,
                NewEmailSendResponseReport.originalHeaders,
                NewEmailSendResponseReport.body
            from OriginalEmailSend
        returning true
$$;

Commit;
