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

Create domain Identifier integer
    constraint IdentifierC check (value > 0);

Create domain Name varchar(200)
    constraint NameC check (length(value) > 2);

Create table Sender (
    fromAddress EmailAddress not null,
    fromName varchar(200) not null,
    createdAt timestamptz not null default now(),
    returnURLRoot HTTPURL not null,
    returnPath EmailAddress,
    replyTo EmailAddress,
    constraint SenderPK primary key (fromAddress)
);

Create type EmailState as enum (
    'new',
    'cancelled',
    'sent',
    'responseReported',
    'tracked',
    'viewed',
    'redirected',
    'unsubscribed'
);

Create table Subscriber (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    createdAt timestamptz not null default now(),
    revisedAt timestamptz not null default now(),
    locale LocaleCode,
    properties hstore default ''::hstore not null,
    state EmailState not null default 'new',
    constraint SubscriberPK primary key (fromAddress, toAddress),
    constraint SubscriberFK foreign key (fromAddress)
            references Sender on update cascade,
    constraint SubscriberRevisedAtC check (revisedAt >= createdAt)
);

Create sequence EmailId;

Create table Email (
    fromAddress EmailAddress not null,
    emailId Identifier not null default nextval('EmailId'::regclass),
    name Name not null default currval('EmailId'::regclass)::text || '. Name',
    createdAt timestamptz not null default now(),
    bulk boolean not null default false,
    redirectURL HTTPURL,
    locale LocaleCodeArray,
    state EmailState not null default 'new',
    constraint EmailPK primary key (fromAddress, emailId),
    constraint EmailNameUK unique (name, fromAddress),
    constraint EmailFK foreign key (fromAddress)
            references Sender on update cascade,
    constraint EmailStateC check (state <= 'sent')
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
    constraint EmailVariationBodyC check (((plainBody is not null) or (hTMLBody is not null))),
    constraint EmailVariationStateC check (state <= 'sent')
);

Create sequence EmailSendOrder;

Create table EmailSend (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    emailId Identifier not null,
    variationId Identifier,
    revisedAt timestamptz not null default now(),
    state EmailState not null default 'new',
    sendOrder Identifier default nextval('EmailSendOrder'::regclass),
    sentAt timestamptz,
    constraint EmailSendPK primary key (fromAddress, toAddress, emailId),
    constraint EmailSendFK foreign key (fromAddress, emailId)
            references Email on delete cascade on update cascade,
            -- This foreign key is not required when variationId is not null. See the note below
            -- on EmailSendEmailVariationFK.
    constraint EmailSendSubscriberFK foreign key (fromAddress, toAddress)
            references Subscriber on update cascade,
    constraint EmailSendEmailVariationFK foreign key (fromAddress, emailId, variationId)
            references EmailVariation,
            -- This foreign key should be set as "match partial" because we want it to match any of the rows
            -- on EmailVariation, but "match partial" is not implemented to PostgreSQL, yet.
    constraint EmailSendVariationIdC check (variationId is not null or state < 'sent'),
    constraint EmailSendOrderC check (sendOrder is not null or state > 'new'),
    constraint EmailSendSentAtC check (sentAt is not null or state < 'sent'),
    constraint EmailSendRevisedAtC check (revisedAt >= sentAt)
);

Create index EmailSendEmailVariationFKI on EmailSend (fromAddress, emailId, variationId);

Create table EmailSendFeedback (
    fromAddress EmailAddress not null,
    toAddress EmailAddress not null,
    emailId Identifier not null,
    state EmailState not null,
    createdAt timestamptz not null default now(),
    iPAddress inet not null,
    constraint EmailSendFeedbackPK primary key (fromAddress, toAddress, emailId, state),
    constraint EmailSendFeedbackFK foreign key (fromAddress, toAddress, emailId)
            references EmailSend on delete cascade on update cascade,
    constraint EmailSendFeedbackStateC check (state >= 'tracked')
);

Create index EmailSendFeedbackEmailFKI on EmailSendFeedback (fromAddress, emailId, state);

Create unique index EmailSendFeedbackUnsubscribeUK on EmailSendFeedback (fromAddress, toAddress)
    where state = 'unsubscribed';

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
