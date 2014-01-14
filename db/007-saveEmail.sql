Begin;

Alter table Email add column draft boolean not null default false;

Create or replace function NewEmail(
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
Insert into Email (fromName, fromAddress, subject, returnURLRoot, plainBody, hTMLBody, redirectURL, draft)
    values (fromName, fromAddress, subject, returnURLRoot, plainBody, hTMLBody, redirectURL, draft)
    returning *
$$;

Create or replace function ReviseEmail(
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
    set fromName = fromName,
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

Create or replace function GetEmail(emailId integer)
    returns Email
    language sql
    as $$
Select * from Email where id = emailId
$$;

Create or replace function SendTestEmail(
        emailId integer,
        subscriberEmailAddress varchar(200)
    ) returns bigint
    language sql
    as $$
With NewEmailSend as (insert into EmailSend (emailId, subscriberId)
        select Email.id, Subscriber.id
            from Email, Subscriber
                where Email.id = emailId
                        and Email.draft
                        and Subscriber.emailAddress = subscriberEmailAddress
        returning *)
    select count(*) from NewEmailSend
$$;

Create or replace function RemoveTestEmailSend(
        emailId integer
    ) returns bigint
    language sql
    as $$
With RemovedEmailSend as (delete from EmailSend
            using Email
                where Email.id = emailId
                        and Email.draft
                        and EmailSend.emailId = Email.id
        returning *)
    select count(*) from RemovedEmailSend
$$;

Create or replace function SendEmail(
        emailId integer,
        subscriberCount integer,
        locales char(5)[]
    ) returns bigint
    language sql
    as $$
Update Email set draft = false where id = emailId;
With NewEmailSend as (insert into EmailSend (emailId, subscriberId)
        select emailId, id
            from Subscriber
                where exists (select 1 from unnest(locales) as locale
                            where locale is not distinct from Subscriber.locale)
                        and not exists (select 1 from EmailSendFeedback as Feedback
                                    where Feedback.subscriberId = Subscriber.id
                                            and Feedback.type = 'unsubscribe')
        limit subscriberCount
        returning *)
    select count(*) from NewEmailSend
$$;

Commit;

