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
        select Email.id, Email.fromName, Email.fromAddress, Email.createdAt, Email.outgoingServerName,
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
