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

Create or replace function GetEmail(integer)
    returns Email
    language sql
    as $$
Select * from Email where id = $1
$$;

Commit;

