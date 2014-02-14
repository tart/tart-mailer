Begin;

Create domain EmailAddress varchar(200) collate "C" not null
    constraint EmailAddressC check (value ~ '^[^@]+@[^@]+\.[^@]+$');

Create table Project (
    name varchar(200) not null,
    fromName varchar(200) not null,
    emailAddress EmailAddress,
    returnURLRoot varchar(200) not null,
    createdAt timestamptz not null default now(),
    constraint ProjectPK primary key (name),
    constraint ProjectEmailAddressUK unique (emailAddress)
);

Alter table Email
    add column projectName varchar(200),
    add constraint EmailProjectNameFK foreign key (projectName) references Project (name)
            on update cascade;

Alter table Subscriber
    drop constraint SubscriberEmailAddressC,
    alter column emailAddress type emailAddress,
    add column projectName varchar(200),
    add constraint SubscriberProjectNameFK foreign key (projectName) references Project (name)
            on update cascade;

Insert into Project (name, fromName, emailAddress, returnURLRoot, createdAt)
    select fromAddress, min(fromName), fromAddress, min(returnURLRoot), min(createdAt)
        from Email
        group by fromAddress;

Update Email set projectName = fromAddress;

Update Subscriber
    set projectName = Email.projectName
    from Email
    where Email.id = (select emailId from EmailSend
                    where EmailSend.subscriberId = Subscriber.id
                    group by emailId
                    order by count(*) desc
                    limit 1);

Update Subscriber
    set projectName = Email.projectName
    from Email
    where Subscriber.projectName is null
            and Email.id = (select emailId from EmailSend
                            group by emailId
                            order by count(*) desc
                            limit 1);

Create or replace view ProjectDetail as
    with SubscriberStats as (select projectName, count(*) as count
                    from Subscriber
                    group by projectName),
        EmailStats as (select projectName, count(*) as count
                    from Email
                    group by projectName)
        select Project.name, Project.fromName, Project.emailAddress, Project.returnURLRoot, Project.createdAt,
                coalesce(SubscriberStats.count, 0) as subscribers,
                coalesce(EmailStats.count, 0) as emails
            from Project
                left join SubscriberStats on SubscriberStats.projectName = Project.name
                left join EmailStats on EmailStats.projectName = Project.name
                order by Project.name;

Drop view if exists EmailDetail;

Create or replace view EmailDetail as
    with EmailSendFeedbackTypeStats as (select emailId, type, count(*) as count
                    from EmailSendFeedback
                    group by emailId, type
                    order by emailId, type),
        EmailSendFeedbackStats as (select emailId, string_agg(type::text || ': ' || count::text, ' ') as typeCounts
                    from EmailSendFeedbackTypeStats
                    group by emailId),
        EmailSendStats as (select emailId, count(*) as totalCount, sum(sent::int) as sentCount
                    from EmailSend
                    group by emailId),
        EmailSendResponseReportStats as (select emailId, count(*) as count
                    from EmailSendResponseReport
                    group by emailId),
        EmailVariationRankStats as (select EmailVariation.*, count(*) as count
                    from EmailVariation
                        join EmailSend on EmailSend.emailId = EmailVariation.emailId
                                and EmailSend.variationRank = EmailVariation.rank
                    group by EmailVariation.emailId, EmailVariation.rank),
        EmailVariationStats as (select emailId, string_agg(rank::text || ': ' || count::text, ' ') as rankCounts
                    from EmailVariationRankStats
                    group by emailId)
        select Email.id, Email.createdAt,
                Email.projectName as project,
                Email.outgoingServerName as outgoingServer,
                Email.incomingServerName as incomingServer,
                coalesce(EmailSendStats.totalCount, 0) as total,
                coalesce(EmailSendStats.sentCount, 0) as sent,
                coalesce(EmailSendResponseReportStats.count, 0) as responseReports,
                EmailSendFeedbackStats.typeCounts as feedbacks,
                EmailVariationStats.rankCounts as variations
            from Email
                left join EmailSendStats on EmailSendStats.emailId = Email.id
                left join EmailSendFeedbackStats on EmailSendFeedbackStats.emailId = Email.id
                left join EmailSendResponseReportStats on EmailSendResponseReportStats.emailId = Email.id
                left join EmailVariationStats on EmailVariationStats.emailId = Email.id
                order by Email.id;

Alter table Email
    alter column projectName set not null,
    drop column fromName,
    drop column fromAddress,
    drop column returnURLRoot;

Alter table Subscriber
    alter column projectName set not null;

Create or replace function NextEmailToSend(varchar(200))
    returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text
    )
    language sql strict
    as $$
With FirstWaitingEmail as (select EmailSend.*
            from Email
                join EmailSend on EmailSend.emailId = Email.id
                        and not sent
                where Email.outgoingServerName = $1
                order by Email.id, EmailSend.subscriberId
            limit 1
            for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Project.fromName,
            Project.emailAddress,
            Subscriber.emailAddress,
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            Project.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend)
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
                join Project on Email.projectName = Project.name
            join EmailVariation on UpdatedEmailSend.emailId = EmailVariation.emailId
                    and UpdatedEmailSend.variationRank = EmailVariation.rank
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
$$;

Create or replace function ViewEmailBody(text)
    returns text
    language sql strict
    as $$
Select coalesce(FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Project.returnURLRoot, $1),
                FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Project.returnURLRoot, $1))
    from EmailSend
        join Email on EmailSend.emailId = Email.id
            join Project on Email.projectName = Project.name
        join EmailVariation on EmailSend.emailId = EmailVariation.emailId
                and EmailSend.variationRank = EmailVariation.rank
        join Subscriber on EmailSend.subscriberId = Subscriber.id
        where EmailHash(EmailSend) = $1
$$;

Commit;
