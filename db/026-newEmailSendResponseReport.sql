Create or replace function NewEmailSendResponseReport(
        incomingServerName varchar(200),
        fields hstore,
        originalHeaders hstore
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
                        and Subscriber.emailAddress in (NewEmailSendResponseReport.fields -> 'Original-Recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'Original-Recipient', ';', 2)),
                                NewEmailSendResponseReport.fields -> 'Final-Recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'Final-Recipient', ';', 2)),
                                NewEmailSendResponseReport.originalHeaders -> 'To'))
    insert into EmailSendResponseReport (emailId, subscriberId, fields, originalHeaders)
        select emailId, subscriberId, NewEmailSendResponseReport.fields, NewEmailSendResponseReport.originalHeaders
            from OriginalEmailSend
        returning true
$$;
