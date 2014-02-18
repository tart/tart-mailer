Begin;

Alter table Email add column bulk boolean default false;

Update Email set bulk = True
    where id in (select emailId from EmailVariation where not draft);

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

Drop function if exists SendEmail(integer, integer, text[], text[]);

Create or replace function SendBulkEmail(
        emailId integer,
        subscriberCount integer,
        locale text[],
        variation text[]
    ) returns bigint
    language sql
    as $$
With RevisedEmail as (update Email
        set bulk = true
            where id = SendBulkEmail.emailId
        returning *),
    RevisedEmailVariation as (update EmailVariation
        set revisedAt = now(), draft = false
        from Email
            where EmailVariation.emailId = Email.id
                    and EmailVariation.rank = any(SendBulkEmail.variation::smallint[])
        returning *),
    SubscriberWithRowNumber as (select *, row_number() over (order by id) as rowNumber
        from Subscriber
            where exists (select 1 from unnest(SendBulkEmail.locale) as locale
                            where locale is not distinct from Subscriber.locale)
                    and not exists (select 1 from EmailSend
                                where EmailSend.emailId = SendBulkEmail.emailId
                                        and EmailSend.subscriberId = Subscriber.id)
                    and not exists (select 1 from EmailSendFeedback as Feedback
                                where Feedback.subscriberId = Subscriber.id
                                        and Feedback.type = 'unsubscribe')
                    and not exists (select 1 from EmailSendResponseReport as ResponseReport
                                where ResponseReport.subscriberId = Subscriber.id)
        limit SendBulkEmail.subscriberCount),
    RevisedEmailVariationWithRowNumber as (select *, row_number() over (order by rank) as rowNumber,
            count(*) over () as count
        from RevisedEmailVariation),
    NewEmailSend as (insert into EmailSend (emailId, subscriberId, variationRank)
        select SendBulkEmail.emailId, S.id, E.rank
            from SubscriberWithRowNumber as S
                join RevisedEmailVariationWithRowNumber as E on (S.rowNumber - 1) % E.count = E.rowNumber - 1
        returning *)
    select count(*) from NewEmailSend
$$;

Drop function if exists NextEmailToSend(varchar(200));

Create or replace function NextEmailToSend(varchar(200))
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
            Project.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend),
            Email.bulk
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
                join Project on Email.projectName = Project.name
            join EmailVariation on UpdatedEmailSend.emailId = EmailVariation.emailId
                    and UpdatedEmailSend.variationRank = EmailVariation.rank
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
$$;

Commit;
