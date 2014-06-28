Create or replace view SenderStatistics as
    with SubscriberStats as (select fromAddress,
                count(*) as count,
                sum((Subscriber.state not in ('cancelled', 'responseReported', 'unsubscribed'))::int) as allowed
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
            sentAt::date as sentAt,
            count(*) as sent,
            coalesce(sum((state = 'responseReported')::integer), 0) as responseReported,
            coalesce(sum((state = 'tracked')::integer), 0) as tracked,
            coalesce(sum((state = 'viewed')::integer), 0) as viewed,
            coalesce(sum((state = 'redirected')::integer), 0) as redirected,
            coalesce(sum((state = 'unsubscribed')::integer), 0) as unsubscribed
        from EmailSend
            where state >= 'sent'
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view EmailVariationStatistics as
    select EmailVariation.fromAddress,
            EmailVariation.emailId,
            EmailVariation.variationId,
            EmailVariation.state,
            count(EmailSend) as sent,
            coalesce(sum((EmailSend.state = 'responseReported')::integer), 0) as responseReported,
            coalesce(sum((EmailSend.state = 'tracked')::integer), 0) as tracked,
            coalesce(sum((EmailSend.state = 'viewed')::integer), 0) as viewed,
            coalesce(sum((EmailSend.state = 'redirected')::integer), 0) as redirected,
            coalesce(sum((EmailSend.state = 'unsubscribed')::integer), 0) as unsubscribed
        from EmailVariation
            left join EmailSend using (fromAddress, emailId, variationId)
            group by 1, 2, 3
            order by 1, 2, 3;

Create or replace view SubscriberLocaleStatistics as
    select Subscriber.fromAddress,
            Subscriber.locale,
            count(*) as subscribers,
            sum((Subscriber.state = 'responseReported')::int) as responseReporteded,
            sum((Subscriber.state = 'unsubscribed')::int) as unsubscribed,
            sum((Subscriber.state not in ('cancelled', 'responseReported', 'unsubscribed'))::int) as allowed
        from Subscriber
            group by 1, 2
            order by 1, 2;

Create or replace view EmailSubscriberLocaleStatistics as
    select Subscriber.fromAddress,
            Email.emailId,
            Subscriber.locale,
            count(*) as subscribers,
            sum((Subscriber.state = 'responseReported')::int) as responseReported,
            sum((Subscriber.state = 'unsubscribed')::int) as unsubscribed,
            sum((Subscriber.state not in ('cancelled', 'responseReported', 'unsubscribed'))::int) as allowed,
            count(EmailSend) as send,
            sum((Subscriber.state not in ('cancelled', 'responseReported', 'unsubscribed')
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
                count(*) as total,
                sum((state >= 'sent')::int) as sent,
                sum((state = 'responseReported')::int) as responseReported,
                sum((state = 'tracked')::int) as tracked,
                sum((state = 'viewed')::int) as viewed,
                sum((state = 'redirected')::int) as redirected,
                sum((state = 'unsubscribed')::int) as unsubscribed
            from EmailSend
            group by fromAddress, emailId)
        select Email.fromAddress,
                Email.emailId,
                Email.name,
                Email.createdAt,
                Email.bulk,
                Email.state,
                coalesce(EmailVariationStats.count, 0) as variations,
                coalesce(EmailSendStats.total, 0) as total,
                coalesce(EmailSendStats.sent, 0) as sent,
                coalesce(EmailSendStats.responseReported, 0) as responseReported,
                coalesce(EmailSendStats.tracked, 0) as tracked,
                coalesce(EmailSendStats.viewed, 0) as viewed,
                coalesce(EmailSendStats.redirected, 0) as redirected,
                coalesce(EmailSendStats.unsubscribed, 0) as unsubscribed
            from Email
                left join EmailVariationStats using (fromAddress, emailId)
                left join EmailSendStats using (fromAddress, emailId)
                order by 1, 2;
