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

Drop function if exists SubscriberLocaleStats(integer);

Create function SubscriberLocaleStats(integer)
    returns table (
        locale char(5),
        total bigint,
        send bigint
    )
    language sql
    as $$
Select Subscriber.locale, coalesce(count(*), 0), coalesce(count(EmailSend), 0)
    from Subscriber
        left join EmailSend on EmailSend.subscriberId = Subscriber.id
                and EmailSend.emailId = $1
        where not exists (select 1 from EmailSendFeedback as Feedback
                    where Feedback.subscriberId = Subscriber.id
                            and Feedback.type = 'unsubscribe')
                and not exists (select 1 from EmailSendResponseReport as ResponseReport
                            where ResponseReport.subscriberId = Subscriber.id)
        group by Subscriber.locale
        order by Subscriber.locale
$$;

Commit;
