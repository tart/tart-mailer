Begin;

Create extension if not exists hstore;

Create table EmailSendResponseReport (
    emailId integer,
    subscriberId integer not null,
    fields hstore default ''::hstore not null,
    originalHeaders hstore default ''::hstore not null,
    createdAt timestamptz not null default now(),
    constraint EmailSendResponseReportPK primary key (emailId, subscriberId),
    constraint EmailSendResponseReportFK foreign key (emailId, subscriberId) references EmailSend (emailId, subscriberId)
);

Create index EmailSendResponseReportSubscriberIdFKI on EmailSendResponseReport (subscriberId);

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
                        and Email.incomingServerName = NewEmailSendResponseReport.incomingServerName
                        and ((NewEmailSendResponseReport.originalHeaders -> 'Subject') is null
                                or Email.subject = (NewEmailSendResponseReport.originalHeaders -> 'Subject'))
                join Subscriber on EmailSend.subscriberID = Subscriber.id
                        and Subscriber.emailAddress in (NewEmailSendResponseReport.fields -> 'Final-Recipient',
                                trim(split_part(NewEmailSendResponseReport.fields -> 'Final-Recipient', ';', 2)))
                where EmailSend.sent)
    insert into EmailSendResponseReport (emailId, subscriberId, fields, originalHeaders)
        select emailId, subscriberId, NewEmailSendResponseReport.fields, NewEmailSendResponseReport.originalHeaders
            from OriginalEmailSend
        returning true
$$;

Commit;

