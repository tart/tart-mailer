Begin;

Drop function if exists ListOutgoingServers();

Create or replace function ListOutgoingServers()
    returns table (
        name varchar(200),
        hostname varchar(200),
        username varchar(200),
        createdAt timestamptz,
        emailCount bigint
    )
    language sql
    as $$
Select OutgoingServer.name, OutgoingServer.hostname, OutgoingServer.username, OutgoingServer.createdAt,
        count(Email) as emailCount
    from OutgoingServer
        left join Email on Email.outgoingServerName = OutgoingServer.name
    group by OutgoingServer.name
$$;

Drop function if exists ListEmails();

Create or replace function ListEmails()
    returns table (
        id integer,
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        createdAt timestamptz,
        outgoingServerName varchar(200),
        totalCount bigint,
        sentCount bigint,
        feedbackTypeCounts text
    )
    language sql
    as $$
With EmailSendFeedbackTypeStats as (select emailId, type, count(*) as count
                from EmailSendFeedback
                group by emailId, type
                order by emailId, type),
    EmailSendFeedbackStats as (select emailId, string_agg(type::text || ': ' || count::text, ' ') as typeCounts
                from EmailSendFeedbackTypeStats
                group by emailId),
    EmailSendStats as (select emailId, count(*) as totalCount, sum(sent::int) as sentCount
                from EmailSend
                group by emailId)
    select Email.id, Email.fromName, Email.fromAddress, Email.subject, Email.createdAt, Email.outgoingServerName,
            coalesce(EmailSendStats.totalCount, 0) as totalCount,
            coalesce(EmailSendStats.sentCount, 0) as sentCount,
            EmailSendFeedbackStats.typeCounts as feedbackTypeCounts
        from Email
            left join EmailSendStats on EmailSendStats.emailId = Email.id
            left join EmailSendFeedbackStats on EmailSendFeedbackStats.emailId = Email.id
$$;

Commit;

