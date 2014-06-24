Create extension if not exists hstore;

Create domain EmailAddress varchar(200) collate "C"
    constraint EmailAddressC check (value ~ '^[a-z0-9._\-+!'']+@[a-z0-9.\-]+\.[a-z0-9]+$');

Create domain HTTPURL varchar(1000) collate "C"
    constraint HTTPURLC check (value ~ '^(http|https)://');

Create domain LocaleCode varchar(5) collate "C" not null default 'C'
    constraint LocaleCodeFormatC check (value ~ '^([a-z]{2}_[A-Z]{2}|C)$');

Create domain LocaleCodeArray varchar(5)[] collate "C" not null default '{C}'
    constraint LocaleCodeArrayNullC check (null !== all (value))
    constraint LocaleCodeArrayFormatC check ('^([a-z]{2}_[A-Z]{2}|C)$' ^~ all (value));

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

Create type EmailState as enum (
    'new',
    'send',
    'cancel'
);

Create table Email (
    fromAddress EmailAddress not null,
    emailId Identifier not null,
    name Name not null,
    createdAt timestamptz not null default now(),
    bulk boolean not null default false,
    redirectURL HTTPURL,
    locale LocaleCodeArray,
    state EmailState not null default 'new',
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
    state EmailState not null default 'new',
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
    variationId Identifier,
    revisedAt timestamptz not null default now(),
    sent boolean not null default false,
    constraint EmailSendPK primary key (fromAddress, toAddress, emailId),
    constraint EmailSendFK foreign key (fromAddress, emailId)
            references Email on delete cascade on update cascade, -- This foreign key is not required when variationId
                                                                  -- is not null. See the note below
                                                                  -- on EmailSendEmailVariationFK.
    constraint EmailSendSubscriberFK foreign key (fromAddress, toAddress)
            references Subscriber on update cascade,
    constraint EmailSendEmailVariationFK foreign key (fromAddress, emailId, variationId)
            references EmailVariation -- This foreign key should be set as "match partial" because we want it to match
                                      -- any of the rows on EmailVariation, but "match partial" is not implemented to
                                      -- PostgreSQL, yet.
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
