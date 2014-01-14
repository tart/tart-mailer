Begin;

Alter table Email add column draft boolean not null default false;

Create or replace function NewEmail(
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        returnURLRoot varchar(1000),
        redirectURL varchar(1000)
    ) returns Email
    language sql
    as $$
Insert into Email (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL)
    values (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL)
    returning *
$$;

Create or replace function ReviseEmail(
        emailId integer,
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        returnURLRoot varchar(1000),
        redirectURL varchar(1000)
    ) returns Email
    language sql
    as $$
Update Email
    set fromName = fromName,
            fromAddress = fromAddress,
            subject = subject,
            plainBody = plainBody,
            hTMLBody = hTMLBody,
            returnURLRoot = returnURLRoot,
            redirectURL = redirectURL,
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
        maxSubscriberId integer
    ) returns bigint
    language sql
    as $$
Update Email set draft = false where id = emailId;
With NewEmailSend as (insert into EmailSend (emailId, subscriberId)
        select emailId, id
            from Subscriber
                where id <= maxSubscriberId
                        and not exists (select 1 from EmailSendFeedback as Feedback
                                    where Feedback.subscriberId = Subscriber.id
                                            and Feedback.type = 'unsubscribe')
        returning *)
    select count(*) from NewEmailSend
$$;

Commit;

