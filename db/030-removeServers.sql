Begin;

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
        select Email.id, Email.createdAt, Email.bulk,
                Email.projectName as project,
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
    drop column incomingServerName,
    drop column outgoingServerName;

Drop table IncomingServer;
Drop table OutgoingServer;

Drop function if exists RemoveNotAllowedEmailSend(varchar);

Create or replace function RemoveNotAllowedEmailSend(projectName varchar(200) default null)
    returns setof EmailSend
    language sql
    as $$
Delete from EmailSend
    where not sent
            and (RemoveNotAllowedEmailSend.projectName is null
                    or emailId in (select id from Email where projectName = RemoveNotAllowedEmailSend.projectName))
            and (subscriberId in (select subscriberId from EmailSendFeedback where type = 'unsubscribe')
                    or subscriberId in (select subscriberId from EmailSendResponseReport))
    returning *
$$;

Drop function if exists NextEmailToSend(varchar);

Create or replace function NextEmailToSend(projectName varchar(200) default null)
    returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text,
        bulk boolean
    )
    language sql
    as $$
With FirstWaitingEmail as (select EmailSend.*
            from Email
                join EmailSend on EmailSend.emailId = Email.id
                        and not sent
                where NextEmailToSend.projectName is null
                        or Email.projectName = NextEmailToSend.projectName
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
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Project.returnURLRoot, EmailHash(UpdatedEmailSend)),
            Project.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend),
            Email.bulk
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
                join Project on Email.projectName = Project.name
            join EmailVariation on UpdatedEmailSend.emailId = EmailVariation.emailId
                    and UpdatedEmailSend.variationRank = EmailVariation.rank
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
$$;

Create or replace function EmailToSendCount(projectName varchar(200) default null)
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend
    where not sent and (EmailToSendCount.projectName is null or projectName = EmailToSendCount.projectName)
$$;

Commit;
