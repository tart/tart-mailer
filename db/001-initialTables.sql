Begin;

Create extension if not exists hstore;

Create type EmailSendStatus as enum (
    'waiting',
    'sent'
);

Create table Email (
    id integer not null,
    fromAddress varchar(200) not null,
    title varchar(1000) not null,
    plainBody text,
    hTMLBody text,
    createdAt timestamp with time zone default now() not null,
    revisedAt timestamp with time zone default now() not null,
    constraint emailpk primary key (id),
    constraint EmailBodyC CHECK (((plainbody IS not null) OR (hTMLBody IS NOT NULL)))
);

Create sequence EmailId owned by Email.id;
Alter table Email alter id set default nextval('EmailId'::regclass);

Create type SubscriberStatus as enum (
    'subscribed',
    'unsubscribed'
);

Create table Subscriber (
    id integer not null,
    emailAddress varchar(200) not null,
    createdAt timestamp with time zone default now(),
    revisedAt timestamp with time zone default now(),
    status SubscriberStatus not null default 'subscribed',
    locale char(5),
    properties hstore default ''::hstore not null,
    constraint subscriberpk primary key (id),
    constraint subscriberemailaddressuk unique (emailaddress)
);

Create sequence SubscriberId owned by Subscriber.id;
Alter table Subscriber alter id set default nextval('SubscriberId'::regclass);

Create table EmailSend (
    emailId integer not null,
    subscriberId integer not null,
    status emailsendstatus default 'waiting'::EmailSendStatus not null,
    constraint EmailSendPK primary key (emailId, subscriberId),
    constraint EmailSendFK foreign key (emailId) references Email (id) on delete cascade,
    constraint EmailSendSubscriberIdFK foreign key (subscriberId) references Subscriber (id)
);

Create index EmailSendSubscriberIdFKI on EmailSend (subscriberId);

Commit;

