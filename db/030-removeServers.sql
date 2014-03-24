Begin;

Create or replace view SenderDetail as
    with SubscriberStats as (select fromAddress, count(*) as count
            from Subscriber
            group by fromAddress),
        EmailStats as (select fromAddress, count(*) as totalCount, sum(bulk::int) as bulkCount
            from Email
            group by fromAddress)
        select Sender.*,
                coalesce(SubscriberStats.count, 0) as subscribers,
                coalesce(EmailStats.bulkCount, 0) as bulkEmails,
                coalesce(EmailStats.totalCount, 0) as totalEmails
            from Sender
                left join SubscriberStats using (fromAddress)
                left join EmailStats using (fromAddress)
            order by Sender.fromAddress;

Create or replace view EmailDetail as
    with EmailSendStats as (select fromAddress, emailId, count(*) as totalCount, sum(sent::int) as sentCount
            from EmailSend
            group by fromAddress, emailId),
        EmailFeedbackTypeStats as (select fromAddress, emailId, feedbackType, count(*) as count
            from EmailSendFeedback
            group by fromAddress, emailId, feedbackType),
        EmailResponseReportStats as (select fromAddress, emailId, count(*) as count
            from EmailSendResponseReport
            group by fromAddress, emailId),
        EmailFeedbackStats as (select fromAddress, emailId,
                    string_agg(feedbackType::text || ': ' || count::text, ' ') as counts
            from EmailFeedbackTypeStats
            group by fromAddress, emailId),
        EmailVariationIdStats as (select EmailVariation.*, count(*) as count
            from EmailVariation
                join EmailSend using (fromAddress, emailId, variationId)
            group by EmailVariation.fromAddress, EmailVariation.emailId, EmailVariation.variationId),
        EmailVariationStats as (select fromAddress, emailId,
                string_agg(variationId::text || ': ' || count::text, ' ') as counts
            from EmailVariationIdStats
            group by fromAddress, emailId)
        select Email.fromAddress, Email.emailId, Email.createdAt, Email.bulk,
                coalesce(EmailSendStats.totalCount, 0) as totalMessages,
                coalesce(EmailSendStats.sentCount, 0) as sentMessages,
                coalesce(EmailResponseReportStats.count, 0) as responseReports,
                EmailFeedbackStats.counts as feedbacks,
                EmailVariationStats.counts as variations
            from Email
                left join EmailSendStats using (fromAddress, emailId)
                left join EmailFeedbackStats using (fromAddress, emailId)
                left join EmailResponseReportStats using (fromAddress, emailId)
                left join EmailVariationStats using (fromAddress, emailId)
                order by Email.fromAddress, Email.emailId;

Create or replace function RemoveNotAllowedEmailSend()
    returns setof EmailSend
    language sql strict
    as $$
Delete from EmailSend
    where not sent
            and (toAddress in (select toAddress from EmailSendFeedback
                        where feedbackType = 'unsubscribe')
                    or toAddress in (select toAddress from EmailSendResponseReport))
    returning *
$$;

Create or replace function RemoveNotAllowedEmailSend(fromAddress varchar(200))
    returns setof EmailSend
    language sql strict
    as $$
Delete from EmailSend
    where not sent
            and fromAddress = RemoveNotAllowedEmailSend.fromAddress
            and (toAddress in (select toAddress from EmailSendFeedback
                        where fromAddress = RemoveNotAllowedEmailSend.fromAddress
                                and feedbackType = 'unsubscribe')
                    or toAddress in (select toAddress from EmailSendResponseReport
                        where fromAddress = RemoveNotAllowedEmailSend.fromAddress))
    returning *
$$;

Create or replace function NextEmailToSend(fromAddress varchar(200) default null)
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
        from EmailSend
            where not sent
                    and (NextEmailToSend.fromAddress is null or fromAddress = NextEmailToSend.fromAddress)
        limit 1
        for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Sender.fromName,
            Sender.fromAddress,
            Subscriber.toAddress,
            FormatEmailToSend(EmailVariation.subject, Subscriber.properties),
            FormatEmailToSend(EmailVariation.plainBody, Subscriber.properties, Sender.returnURLRoot, EmailHash(UpdatedEmailSend)),
            FormatEmailToSend(EmailVariation.hTMLBody, Subscriber.properties, Sender.returnURLRoot, EmailHash(UpdatedEmailSend)),
            Sender.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend),
            Email.bulk
        from UpdatedEmailSend
            join Sender using (fromAddress)
            join Email using (fromAddress, emailId)
            join EmailVariation using (fromAddress, emailId, variationId)
            join Subscriber using (fromAddress, toAddress)
$$;

Create or replace function EmailToSendCount()
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend where not sent
$$;

Create or replace function EmailToSendCount(fromAddress varchar(200))
    returns bigint
    language sql
    as $$
Select count(*) from EmailSend where not sent and fromAddress = EmailToSendCount.fromAddress
$$;

Commit;
