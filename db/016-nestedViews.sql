Create or replace view NestedEmail as
    with EmailVariations as (select fromAddress, emailId,
                    array_agg(EmailVariation) as variations
                from EmailVariation
                group by fromAddress, emailId)
    select Email.*,
            coalesce(variations, '{}'::EmailVariation[]) as variations
        from Email
            left join EmailVariations using (fromAddress, emailId);

Create or replace view NestedEmailSend as
    with EmailSendFeedbacks as (select fromAddress, toAddress, emailId,
                    array_agg(EmailSendFeedback) as feedbacks
                from EmailSendFeedback
                group by fromAddress, toAddress, emailId),
        EmailSendResponseReports as (select fromAddress, toAddress, emailId,
                    array_agg(EmailSendResponseReport) as responseReports
                from EmailSendResponseReport
                group by fromAddress, toAddress, emailId)
    select EmailSend.*,
            coalesce(feedbacks, '{}'::EmailSendFeedback[]) as feedbacks,
            coalesce(responseReports, '{}'::EmailSendResponseReport[]) as responseReports
        from EmailSend
            left join EmailSendFeedbacks using (fromAddress, toAddress, emailId)
            left join EmailSendResponseReports using (fromAddress, toAddress, emailId);
