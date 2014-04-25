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
