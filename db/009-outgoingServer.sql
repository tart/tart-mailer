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

Create or replace function OutgoingServerNames()
    returns varchar(200)[]
    language sql
    as $$
Select array_agg(name order by name) from OutgoingServer;
$$;

Commit;

