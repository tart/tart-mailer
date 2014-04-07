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

Create or replace view BulkEmailDetail as
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
        select Email.fromAddress, Email.emailId, Email.createdAt,
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
                where Email.bulk
                order by Email.fromAddress, Email.emailId;
