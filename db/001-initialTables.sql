Begin;

Create extension if not exists hstore;

Create table Email (
    id integer not null,
    fromName varchar(200) not null,
    fromAddress varchar(200) not null,
    subject varchar(1000) not null,
    plainBody text,
    hTMLBody text,
    returnURLRoot varchar(1000) not null,
    redirectURL varchar(1000),
    createdAt timestamp with time zone default now() not null,
    revisedAt timestamp with time zone default now() not null,
    constraint EmailPK primary key (id),
    constraint EmailBodyC check (((plainBody is not null) or (hTMLBody is not null))),
    constraint EmailCreatedAtC check (createdAt >= now()) not valid,
    constraint EmailRevisedAtC check (revisedAt >= createdAt),
    constraint EmailReturnURLRootC check (returnURLRoot ~ '^(http|https)://' and returnURLRoot ~ '/$'),
    constraint EmailRedirectURLC check (redirectURL~ '^(http|https)://')
);

Create sequence EmailId owned by Email.id;
Alter table Email alter id set default nextval('EmailId'::regclass);

Create type SubscriberStatus as enum (
    'subscribed',
    'unsubscribed'
);

Create table Subscriber (
    id integer not null,
    fullName varchar(200) not null,
    emailAddress varchar(200) not null,
    createdAt timestamp with time zone default now(),
    revisedAt timestamp with time zone default now(),
    status SubscriberStatus not null default 'subscribed',
    locale char(5),
    properties hstore default ''::hstore not null,
    constraint SubscriberPK primary key (id),
    constraint SubscriberEmailAddressUK unique (emailAddress),
    constraint SubscriberEmailAddressC check (emailAddress ~ '^[^@]+@[^@]+\.[^@]+$'),
    constraint SubscriberCreatedAtC check (createdAt >= now()) not valid,
    constraint SubscriberRevisedAtC check (revisedAt >= createdAt),
    constraint SubscriberLocaleC check (locale ~ '^[a-z]{2}_[A-Z]{2}$')
);

Create sequence SubscriberId owned by Subscriber.id;
Alter table Subscriber alter id set default nextval('SubscriberId'::regclass);

Create type EmailSendStatus as enum (
    'waiting',
    'sent',
    'trackerImageDisplayed',
    'redirected',
    'unsubscribed'
);

Create table EmailSend (
    emailId integer not null,
    subscriberId integer not null,
    status emailsendstatus not null default 'waiting'::EmailSendStatus,
    constraint EmailSendPK primary key (emailId, subscriberId),
    constraint EmailSendFK foreign key (emailId) references Email (id) on delete cascade,
    constraint EmailSendSubscriberIdFK foreign key (subscriberId) references Subscriber (id)
);

Create table EmailSendFeedback (
    emailId integer not null,
    subscriberId integer not null,
    createdAt timestamptz not null default now(),
    status EmailSendStatus not null,
    iPAddress inet not null,
    constraint EmailSendFeedbackPK primary key (emailId, subscriberId, status),
    constraint EmailSendFeedbackFK foreign key (emailId, subscriberId) references EmailSend (emailId, subscriberId) on delete cascade,
    constraint EmailSendCreatedAtC check (createdAt >= now()) not valid,
    constraint EmailSendFeedbackStatusC check (status > 'sent')
);

Create index EmailSendFeedbackSubscriberIdFKI on EmailSendFeedback (subscriberId, status);

Commit;

