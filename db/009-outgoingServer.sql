Begin;

Create table OutgoingServer (
    name varchar(200) not null,
    hostname varchar(200) not null,
    port smallint not null,
    useTLS boolean not null default false,
    username varchar(200),
    password varchar(200),
    createdAt timestamptz default now() not null,
    constraint OutgoingServerPK primary key (name),
    constraint OutgoingServerPasswordC check ((password is null) = (password is null))
);

Alter table Email add column outgoingServerName varchar(200),
        add constraint EmailOutgoingServerNameFK foreign key (outgoingServerName) references OutgoingServer (name);

Insert into OutgoingServer (name, hostname, port)
    values ('localhost', 'localhost', 25);

Update Email set outgoingServerName = 'localhost';

Alter table Email alter column outgoingServerName set not null;

Commit;
