Begin;

Create table IncomingServer (
    name varchar(200) not null,
    hostname varchar(200) not null,
    port smallint not null,
    username varchar(200),
    password varchar(200),
    mailbox varchar(200),
    createdAt timestamp with time zone default now() not null,
    constraint IncomingServerPK primary key (name),
    constraint IncomingServerPasswordC check ((password is null) = (password is null))
);

Alter table Email add column incomingServerName varchar(200),
        add constraint EmailIncomingServerNameFK foreign key (incomingServerName) references IncomingServer (name);

Create or replace function ListIncomingServers()
    returns setof IncomingServer
    language sql
    as $$
Select * from IncomingServe
$$;

Create or replace function IncomingServerToReceive(varchar(200))
    returns setof IncomingServer 
    language sql
    as $$
Select * from IncomingServer where name = $1
$$;

Create or replace function NewEmail(
        outgoingServerName varchar(200),
        incomingServerName varchar(200),
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        returnURLRoot varchar(1000),
        plainBody text default null,
        hTMLBody text default null,
        redirectURL varchar(1000) default null,
        draft boolean default true
    ) returns setof Email
    language sql
    as $$
Insert into Email (outgoingServerName, incomingServerName, fromName, fromAddress, subject, returnURLRoot,
        plainBody, hTMLBody, redirectURL, draft)
    values (outgoingServerName, incomingServerName, fromName, fromAddress, subject, returnURLRoot,
            plainBody, hTMLBody, redirectURL, draft)
    returning *
$$;

Create or replace function ReviseEmail(
        outgoingServerName varchar(200),
        incomingServerName varchar(200),
        emailId integer,
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        returnURLRoot varchar(1000),
        plainBody text default null,
        hTMLBody text default null,
        redirectURL varchar(1000) default null,
        draft boolean default true
    ) returns setof Email
    language sql
    as $$
Update Email
    set outgoingServerName = outgoingServerName,
            incomingServerName = incomingServerName,
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

