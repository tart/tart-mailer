Create or replace view SenderStatistics as
    with SubscriberStats as (select fromAddress,
                count(*) as count,
                sum((Subscriber.state not in ('responseReport', 'unsubscribe'))::int) as allowed
            from Subscriber
            group by fromAddress),
        EmailStats as (select fromAddress, count(*) as totalCount, sum(bulk::int) as bulkCount
            from Email
            group by fromAddress)
        select Sender.fromAddress, Sender.fromName, Sender.createdAt,
                coalesce(SubscriberStats.count, 0) as subscribers,
                coalesce(SubscriberStats.allowed, 0) as allowed,
                coalesce(EmailStats.bulkCount, 0) as bulkEmails,
                coalesce(EmailStats.totalCount, 0) as totalEmails
            from Sender
                left join SubscriberStats using (fromAddress)
                left join EmailStats using (fromAddress)
            order by Sender.fromAddress;

Create or replace view EmailSentDateStatistics as
    select EmailSend.fromAddress,
            EmailSend.emailId,
            EmailSend.revisedAt::date as sentDate,
            count(*) as total,
            count(EmailSendResponseReport) as responseReports,
            coalesce(sum((EmailSendFeedback.feedbackType = 'trackerImage')::integer), 0) as trackerImages,
            coalesce(sum((EmailSendFeedback.feedbackType = 'view')::integer), 0) as views,
            coalesce(sum((EmailSendFeedback.feedbackType = 'redirect')::integer), 0) as redirects,
            coalesce(sum((EmailSendFeedback.feedbackType = 'unsubscribe')::integer), 0) as unsubscribes
        from EmailSend
            left join EmailSendResponseReport using (fromAddress, toAddress, emailId)
            left join EmailSendFeedback using (fromAddress, toAddress, emailId)
            where EmailSend.sent
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view EmailVariationStatistics as
    select EmailVariation.fromAddress,
            EmailVariation.emailId,
            EmailVariation.variationId,
            EmailVariation.state,
            count(EmailSend) as send,
            coalesce(sum((EmailSend.sent)::integer), 0) as sent,
            count(EmailSendResponseReport) as responseReports,
            coalesce(sum((EmailSendFeedback.feedbackType = 'trackerImage')::integer), 0) as trackerImages,
            coalesce(sum((EmailSendFeedback.feedbackType = 'view')::integer), 0) as views,
            coalesce(sum((EmailSendFeedback.feedbackType = 'redirect')::integer), 0) as redirects,
            coalesce(sum((EmailSendFeedback.feedbackType = 'unsubscribe')::integer), 0) as unsubscribes
        from EmailVariation
            left join EmailSend using (fromAddress, emailId, variationId)
                left join EmailSendResponseReport using (fromAddress, toAddress, emailId)
                left join EmailSendFeedback using (fromAddress, toAddress, emailId)
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view SubscriberLocaleStatistics as
    select Subscriber.fromAddress,
            Subscriber.locale,
            count(*) as subscribers,
            sum((Subscriber.state = 'responseReport')::int) as responseReported,
            sum((Subscriber.state = 'unsubscribe')::int) as unsubscribed,
            sum((Subscriber.state != 'responseReport'
                    and Subscriber.state != 'unsubscribe')::int) as allowed
        from Subscriber
            group by 1, 2
            order by 1, 2;

Create or replace view EmailSubscriberLocaleStatistics as
    select Subscriber.fromAddress,
            Email.emailId,
            Subscriber.locale,
            count(*) as subscribers,
            sum((Subscriber.state = 'responseReport')::int) as responseReported,
            sum((Subscriber.state = 'unsubscribe')::int) as unsubscribed,
            sum((Subscriber.state != 'responseReport'
                    and Subscriber.state != 'unsubscribe')::int) as allowed,
            count(EmailSend) as send,
            sum((Subscriber.state != 'responseReport'
                    and Subscriber.state != 'unsubscribe'
                    and EmailSend is null)::int) as remaining
        from Subscriber
            join Email using (fromAddress)
                left join EmailSend using (fromAddress, toAddress, emailId)
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view EmailStatistics as
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
        select Email.fromAddress,
                Email.emailId,
                Email.name,
                Email.createdAt,
                Email.bulk,
                Email.state,
                coalesce(EmailVariationStats.count, 0) as variations,
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
                order by 1, 2;
