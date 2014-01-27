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

Commit;

