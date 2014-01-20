Begin;

Create table OutgoingServer (
    name varchar(200) not null,
    hostname varchar(200) not null,
    port smallint not null,
    useTLS boolean not null default false,
    username varchar(200),
    password varchar(200),
    createdAt timestamp with time zone default now() not null,
    constraint OutgoingServerPK primary key (name),
    constraint OutgoingServerPasswordC check ((password is null) = (password is null))
);

Alter table Email add column outgoingServerName varchar(200),
        add constraint EmailOutgoingServerNameFK foreign key (outgoingServerName) references OutgoingServer (name);

Insert into OutgoingServer (name, hostname, port)
    values ('localhost', 'localhost', 25);

Update Email set outgoingServerName = 'localhost';

Alter table Email alter column outgoingServerName set not null;

Create index EmailOutgoingServerNameFKI on Email (outgoingServerName);

Create or replace function ListOutgoingServers()
    returns table (
        name varchar(200),
        hostname varchar(200),
        createdAt timestamptz,
        emailCount bigint,
        totalCount bigint,
        sentCount bigint
    )
    language sql
    as $$
Select OutgoingServer.name, OutgoingServer.hostname, OutgoingServer.createdAt,
        coalesce(count(distinct Email), 0) as emailCount,
        coalesce(count(EmailSend), 0) as totalCount,
        coalesce(sum(EmailSend.sent::int), 0) as sentCount
    from OutgoingServer
        left join Email on Email.outgoingServerName = OutgoingServer.name
            left join EmailSend on EmailSend.emailId = Email.id
    group by OutgoingServer.name
$$;

Create or replace function OutgoingServerToSend(varchar(200))
    returns table (
        hostname varchar(200),
        port smallint,
        useTLS boolean,
        username varchar(200),
        password varchar(200),
        totalCount bigint
    )
    language sql
    as $$
Select OutgoingServer.hostname,
        OutgoingServer.port,
        OutgoingServer.useTLS,
        OutgoingServer.username,
        OutgoingServer.password,
        count(*) as totalCount
    from OutgoingServer
        join Email on Email.outgoingServerName = OutgoingServer.name
            join EmailSend on EmailSend.emailId = Email.id
                    and not EmailSend.sent
        where OutgoingServer.name = $1
    group by OutgoingServer.name
$$;

Create or replace function NextEmailToSend(varchar(200))
    returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text
    )
    language sql
    as $$
With FirstWaitingEmail as (select EmailSend.*
            from Email
                join EmailSend on EmailSend.emailId = Email.id
                        and not sent
                where Email.outgoingServerName = $1
                order by Email.draft desc, Email.id, EmailSend.subscriberId
            limit 1
            for update),
    UpdatedEmailSend as (update EmailSend
            set sent = true
            from FirstWaitingEmail
                where EmailSend = FirstWaitingEmail
            returning EmailSend.*)
    select Email.fromName,
            Email.fromAddress,
            Subscriber.emailAddress as toAddress,
            FormatEmailToSend(Email.subject, Formatter.k, Formatter.v) as subject,
            FormatEmailToSend(Email.plainBody, Formatter.k, Formatter.v) as plainBody,
            FormatEmailToSend(Email.hTMLBody, Formatter.k, Formatter.v) as hTMLBody
        from UpdatedEmailSend
            join Email on UpdatedEmailSend.emailId = Email.id
            join Subscriber on UpdatedEmailSend.subscriberId = Subscriber.id
                cross join lateral (select array_agg(key) as k, array_agg(value) as v
                    from ((select * from each(Subscriber.properties))
                        union values ('unsubscribeurl',
                                    Email.returnURLRoot || 'unsubscribe/' || EmailHash(UpdatedEmailSend)),
                                ('redirecturl',
                                    Email.returnURLRoot || 'redirect/' || EmailHash(UpdatedEmailSend)),
                                ('trackerimageurl',
                                    Email.returnURLRoot || 'trackerImage/' ||
                                                EmailHash(UpdatedEmailSend))) as A) as Formatter
$$;

Create or replace function OutgoingServerNames()
    returns varchar(200)[]
    language sql
    as $$
Select array_agg(name order by name) from OutgoingServer;
$$;

Create or replace function NewEmail(
        outgoingServerName varchar(200),
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        returnURLRoot varchar(1000),
        plainBody text default null,
        hTMLBody text default null,
        redirectURL varchar(1000) default null,
        draft boolean default true
    ) returns Email
    language sql
    as $$
Insert into Email (outgoingServerName, fromName, fromAddress, subject, returnURLRoot,
        plainBody, hTMLBody, redirectURL, draft)
    values (outgoingServerName, fromName, fromAddress, subject, returnURLRoot,
            plainBody, hTMLBody, redirectURL, draft)
    returning *
$$;

Create or replace function ReviseEmail(
        outgoingServerName varchar(200),
        emailId integer,
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        returnURLRoot varchar(1000),
        plainBody text default null,
        hTMLBody text default null,
        redirectURL varchar(1000) default null,
        draft boolean default true
    ) returns Email
    language sql
    as $$
Update Email
    set outgoingServerName = outgoingServerName,
            fromName = fromName,
            fromAddress = fromAddress,
            subject = subject,
            returnURLRoot = returnURLRoot,
            plainBody = plainBody,
            hTMLBody = hTMLBody,
            redirectURL = redirectURL,
            draft = draft,
            revisedAt = now()
    where id = emailId
    returning *
$$;

Commit;

