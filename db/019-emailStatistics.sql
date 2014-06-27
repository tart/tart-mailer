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
    select fromAddress,
            emailId,
            revisedAt::date as sentDate,
            count(*) as total,
            coalesce(sum((state = 'responseReport')::integer), 0) as responseReports,
            coalesce(sum((state = 'trackerImage')::integer), 0) as trackerImages,
            coalesce(sum((state = 'view')::integer), 0) as views,
            coalesce(sum((state = 'redirect')::integer), 0) as redirects,
            coalesce(sum((state = 'unsubscribe')::integer), 0) as unsubscribes
        from EmailSend
            where state >= 'sent'
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view EmailVariationStatistics as
    select EmailVariation.fromAddress,
            EmailVariation.emailId,
            EmailVariation.variationId,
            EmailVariation.state,
            count(EmailSend) as send,
            coalesce(sum((EmailSend.state >= 'sent')::integer), 0) as sent,
            coalesce(sum((EmailSend.state = 'responseReport')::integer), 0) as responseReports,
            coalesce(sum((EmailSend.state = 'trackerImage')::integer), 0) as trackerImages,
            coalesce(sum((EmailSend.state = 'view')::integer), 0) as views,
            coalesce(sum((EmailSend.state = 'redirect')::integer), 0) as redirects,
            coalesce(sum((EmailSend.state = 'unsubscribe')::integer), 0) as unsubscribes
        from EmailVariation
            left join EmailSend using (fromAddress, emailId, variationId)
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
        EmailSendStats as (select fromAddress,
                emailId,
                count(*) as totalCount,
                sum((state >= 'sent')::int) as sentCount,
                sum((state = 'responseReport')::int) as responseReportCount,
                sum((state = 'trackerImage')::int) as trackerImageCount,
                sum((state = 'view')::int) as viewCount,
                sum((state = 'redirect')::int) as redirectCount,
                sum((state = 'unsubscribe')::int) as unsubscribeCount
            from EmailSend
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
                coalesce(EmailSendStats.responseReportCount, 0) as responseReports,
                coalesce(EmailSendStats.trackerImageCount, 0) as trackerImages,
                coalesce(EmailSendStats.viewCount, 0) as views,
                coalesce(EmailSendStats.redirectCount, 0) as redirects,
                coalesce(EmailSendStats.unsubscribeCount, 0) as unsubscribes
            from Email
                left join EmailVariationStats using (fromAddress, emailId)
                left join EmailSendStats using (fromAddress, emailId)
                order by 1, 2;
