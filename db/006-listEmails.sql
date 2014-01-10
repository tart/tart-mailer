Begin;

Create or replace function ListEmails()
    returns table (
        id integer,
        fromName varchar(200),
        subject varchar(1000),
        createdAt timestamptz,
        stats hstore
    )
    language sql
    as $$
Select Email.id, Email.fromName, Email.subject, Email.createdAt,
        hstore(array_agg(EmailSendStats.status::text), array_agg(EmailSendStats.count::text)) as stats
    from Email, lateral (select EmailSend.status, count(*) as count
                    from EmailSend
                        where EmailSend.emailId = Email.id
                        group by EmailSend.status) as EmailSendStats
        group by Email.id
        order by Email.id
$$;

Commit;

