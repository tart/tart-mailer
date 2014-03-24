Begin;

Create or replace view EmailSentDateStatistics as
    select EmailSend.fromAddress, EmailSend.emailId, EmailSend.revisedAt::date as sentDate,
            count(*) as total,
            count(EmailSendResponseReport) as responseReports,
            sum((EmailSendFeedback.feedbackType = 'trackerImage')::int) as trackerImages,
            sum((EmailSendFeedback.feedbackType = 'view')::int) as views,
            sum((EmailSendFeedback.feedbackType = 'redirect')::int) as redirects,
            sum((EmailSendFeedback.feedbackType = 'unsubscribe')::int) as unsubscribes
        from EmailSend
            left join EmailSendResponseReport using (fromAddress, toAddress, emailId)
            left join EmailSendFeedback using (fromAddress, toAddress, emailId)
            where EmailSend.sent
            group by EmailSend.fromAddress, EmailSend.emailId, EmailSend.revisedAt::date
            order by EmailSend.fromAddress, EmailSend.emailId, EmailSend.revisedAt::date;

Create or replace view EmailVariationStatistics as
    select EmailSend.fromAddress, EmailSend.emailId, EmailSend.variationId,
            count(*) as total,
            count(EmailSendResponseReport) as responseReports,
            sum((EmailSendFeedback.feedbackType = 'trackerImage')::int) as trackerImages,
            sum((EmailSendFeedback.feedbackType = 'view')::int) as views,
            sum((EmailSendFeedback.feedbackType = 'redirect')::int) as redirects,
            sum((EmailSendFeedback.feedbackType = 'unsubscribe')::int) as unsubscribes
        from EmailSend
            left join EmailSendResponseReport using (fromAddress, toAddress, emailId)
            left join EmailSendFeedback using (fromAddress, toAddress, emailId)
            where EmailSend.sent
            group by EmailSend.fromAddress, EmailSend.emailId, EmailSend.variationId
            order by EmailSend.fromAddress, EmailSend.emailId, EmailSend.variationId;

Commit;
