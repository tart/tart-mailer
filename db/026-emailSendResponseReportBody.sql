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
                        and ((NewEmailSendResponseReport.originalHeaders -> 'subject') is null
                                or FormatEmailToSend(EmailVariation.subject, Subscriber.properties) =
                                        (NewEmailSendResponseReport.originalHeaders -> 'subject'))
                        and (Subscriber.emailAddress in (NewEmailSendResponseReport.fields -> 'original-recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'original-recipient', ';', 2)),
                                NewEmailSendResponseReport.fields -> 'original-rcpt-to',
                                NewEmailSendResponseReport.fields -> 'rinal-recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'final-recipient', ';', 2)),
                                NewEmailSendResponseReport.originalHeaders -> 'to')
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
