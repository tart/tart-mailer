Create or replace view SenderDetail as
    with SubscriberStats as (select fromAddress, count(*) as count
            from Subscriber
            group by fromAddress),
        EmailStats as (select fromAddress, count(*) as totalCount, sum(bulk::int) as bulkCount
            from Email
            group by fromAddress)
        select Sender.fromAddress, Sender.fromName, Sender.createdAt,
                coalesce(SubscriberStats.count, 0) as subscribers,
                coalesce(EmailStats.bulkCount, 0) as bulkEmails,
                coalesce(EmailStats.totalCount, 0) as totalEmails
            from Sender
                left join SubscriberStats using (fromAddress)
                left join EmailStats using (fromAddress)
            order by Sender.fromAddress;

Create or replace view BulkEmailDetail as
    with EmailVariationStats as (select fromAddress, emailId, count(*) as count
            from EmailVariation
            group by fromAddress, emailId),
        EmailSendStats as (select fromAddress, emailId, count(*) as totalCount, sum(sent::int) as sentCount
            from EmailSend
            group by fromAddress, emailId),
        EmailSendResponseReportStats as (select fromAddress, emailId, count(*) as count
            from EmailSendResponseReport
            group by fromAddress, emailId),
        EmailSendFeedbackStats as (select fromAddress, emailId,
                sum((feedbackType = 'trackerImage')::int) as trackerImageCount,
                sum((feedbackType = 'view')::int) as viewCount,
                sum((feedbackType = 'redirect')::int) as redirectCount,
                sum((feedbackType = 'unsubscribe')::int) as unsubscribeCount
            from EmailSendFeedback
            group by fromAddress, emailId)
        select Email.fromAddress, Email.emailId, Email.createdAt,
                EmailVariationStats.count as variations,
                coalesce(EmailSendStats.totalCount, 0) as totalMessages,
                coalesce(EmailSendStats.sentCount, 0) as sentMessages,
                coalesce(EmailSendResponseReportStats.count, 0) as responseReports,
                coalesce(EmailSendFeedbackStats.trackerImageCount, 0) as trackerImages,
                coalesce(EmailSendFeedbackStats.viewCount, 0) as views,
                coalesce(EmailSendFeedbackStats.redirectCount, 0) as redirects,
                coalesce(EmailSendFeedbackStats.unsubscribeCount, 0) as unsubscribes
            from Email
                left join EmailVariationStats using (fromAddress, emailId)
                left join EmailSendStats using (fromAddress, emailId)
                left join EmailSendResponseReportStats using (fromAddress, emailId)
                left join EmailSendFeedbackStats using (fromAddress, emailId)
                where Email.bulk
                order by Email.fromAddress, Email.emailId;
