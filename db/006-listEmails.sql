Begin;

Create extension if not exists hstore;

Create or replace function ListEmails()
    returns table (
        id integer,
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        createdAt timestamptz,
        totalCount bigint,
        sentCount bigint,
        feedbackTypeCounts hstore
    )
    language sql
    as $$
With EmailSendFeedbackTypeStats as (select emailId, type, count(*) as count
            from EmailSendFeedback
            group by emailId, type
            order by emailId, type),
    EmailSendFeedbackStats as (select emailId, hstore(array_agg(type::text), array_agg(count::text)) as typeCounts
            from EmailSendFeedbackTypeStats
            group by emailId),
    EmailSendStats as (select emailId, count(*) as totalCount, count(sent::int) as sentCount
            from EmailSend
            group by emailId)
Select Email.id, Email.fromName, Email.fromAddress, Email.subject, Email.createdAt,
        coalesce(EmailSendStats.totalCount, 0) as totalCount,
        coalesce(EmailSendStats.sentCount, 0) as sentCount,
        EmailSendFeedbackStats.typeCounts as feedbackTypeCounts
    from Email
        left join EmailSendStats on EmailSendStats.emailId = Email.id
        left join EmailSendFeedbackStats on EmailSendFeedbackStats.emailId = Email.id
$$;

Commit;

