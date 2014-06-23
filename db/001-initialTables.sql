Create extension if not exists hstore;

Create domain EmailAddress varchar(200) collate "C"
    constraint EmailAddressC check (value ~ '^[a-z0-9._\-+!'']+@[a-z0-9.\-]+\.[a-z0-9]+$');

Create domain HTTPURL varchar(1000) collate "C"
    constraint HTTPURLC check (value ~ '^(http|https)://');

Create domain LocaleCode char(5) collate "C"
    constraint LocaleCodeC check (value ~ '^[a-z]{2}_[A-Z]{2}$');

Create domain LocaleCodeArray char(5)[] collate "C" not null default array[]::char(5)[]
    constraint LocaleCodeArrayC check ('^[a-z]{2}_[A-Z]{2}$' ^~ all(value));

Create domain Identifier smallint
    constraint IdentifierC check (value > 0);

Create domain Name varchar(200)
    constraint NameC check (length(value) > 2);

Create table Sender (
    fromAddress EmailAddress not null,
    fromName varchar(200) not null,
    createdAt timestamptz not null default now(),
    returnURLRoot HTTPURL not null,
    constraint SenderPK primary key (fromAddress)
);

Create type SubscriberState as enum (
    'new',
    'sent',
    'responseReport',
    'trackerImage',
    'view',
    'redirect',
    'unsubscribe'
);

Create table Subscriber (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    createdAt timestamptz not null default now(),
    revisedAt timestamptz not null default now(),
    locale LocaleCode,
    properties hstore default ''::hstore not null,
    state SubscriberState default 'new',
    constraint SubscriberPK primary key (fromAddress, toAddress),
    constraint SubscriberFK foreign key (fromAddress)
            references Sender on update cascade,
    constraint SubscriberRevisedAtC check (revisedAt >= createdAt)
);

Create table Email (
    fromAddress EmailAddress not null,
    emailId Identifier not null,
    name Name not null,
    createdAt timestamptz not null default now(),
    bulk boolean not null default false,
    redirectURL HTTPURL,
    constraint EmailPK primary key (fromAddress, emailId),
    constraint EmailNameUK unique (name, fromAddress),
    constraint EmailFK foreign key (fromAddress)
            references Sender on update cascade
);

Create table EmailVariation (
    fromAddress EmailAddress not null,
    emailId Identifier not null,
    variationId smallint not null,
    createdAt timestamptz not null default now(),
    revisedAt timestamptz not null default now(),
    subject varchar(1000) not null,
    plainBody text,
    hTMLBody text,
    draft boolean not null default false,
    locale LocaleCodeArray,
    constraint EmailVariationPK primary key (fromAddress, emailId, variationId),
    constraint EmailVariationFK foreign key (fromAddress, emailId)
            references Email on delete cascade on update cascade,
    constraint EmailVariationRevisedAtC check (revisedAt >= createdAt),
    constraint EmailVariationBodyC check (((plainBody is not null) or (hTMLBody is not null)))
);

Create table EmailSend (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    emailId Identifier not null,
    variationId Identifier not null,
    revisedAt timestamptz not null default now(),
    sent boolean not null default false,
    constraint EmailSendPK primary key (fromAddress, toAddress, emailId),
    constraint EmailSendSubscriberFK foreign key (fromAddress, toAddress)
            references Subscriber on update cascade,
    constraint EmailSendEmailVariationFK foreign key (fromAddress, emailId, variationId)
            references EmailVariation
);

Create index EmailSendEmailVariationFKI on EmailSend (fromAddress, emailId, variationId);

Create type EmailSendFeedbackType as enum (
    'trackerImage',
    'view',
    'redirect',
    'unsubscribe'
);

Create cast (EmailSendFeedbackType as SubscriberState)
    with inout as implicit;

Create table EmailSendFeedback (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    emailId Identifier not null,
    feedbackType EmailSendFeedbackType not null,
    createdAt timestamptz not null default now(),
    iPAddress inet not null,
    constraint EmailSendFeedbackPK primary key (fromAddress, toAddress, emailId, feedbackType),
    constraint EmailSendFeedbackFK foreign key (fromAddress, toAddress, emailId)
            references EmailSend on delete cascade on update cascade
);

Create index EmailSendFeedbackEmailFKI on EmailSendFeedback (fromAddress, emailId, feedbackType);

Create unique index EmailSendFeedbackUnsubscribeUK on EmailSendFeedback (fromAddress, toAddress)
    where feedbackType = 'unsubscribe';

Create table EmailSendResponseReport (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    emailId Identifier not null,
    createdAt timestamptz not null default now(),
    fields hstore default ''::hstore not null,
    body text,
    original text,
    constraint EmailSendResponseReportPK primary key (fromAddress, toAddress, emailId),
    constraint EmailSendResponseReportFK foreign key (fromAddress, toAddress, emailId)
            references EmailSend on delete cascade on update cascade
);

Create index EmailSendResponseReportEmailFKI on EmailSendResponseReport (fromAddress, emailId);
