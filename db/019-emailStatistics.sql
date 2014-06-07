Create or replace view SenderStatistics as
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
            EmailVariation.locale,
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

Create or replace view EmailSubscriberLocaleStatistics as
    with SubscriberUnsubscribed as (select fromAddress, toAddress from EmailSendFeedback
                where feedbackType = 'unsubscribe'),
        SubscriberWithResponseReport as (select distinct fromAddress, toAddress from EmailSendResponseReport)
        select Email.fromAddress,
                Email.emailId,
                Subscriber.locale,
                count(*) as subscribers,
                count(SubscriberUnsubscribed) as unsubscribed,
                count(SubscriberWithResponseReport) as responseReported,
                sum((SubscriberUnsubscribed is null
                        and SubscriberWithResponseReport is null)::int) as allowed,
                count(EmailSend) as send,
                sum((SubscriberUnsubscribed is null
                        and SubscriberWithResponseReport is null
                        and EmailSend is null)::int) as remaining
            from Email
                join Subscriber using (fromAddress)
                    left join SubscriberUnsubscribed using (fromAddress, toAddress)
                    left join SubscriberWithResponseReport using (fromAddress, toAddress)
                    left join EmailSend using (fromAddress, toAddress, emailId)
                group by 1, 2, 3
                order by 1, 2, 3;
