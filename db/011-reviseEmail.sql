Create or replace function ReviseEmail(
        emailId integer,
        outgoingServerName varchar(200),
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
With New as (select outgoingServerName, fromName, fromAddress, subject, returnURLRoot,
            plainBody, hTMLBody, redirectURL, draft)
    update Email
        set outgoingServerName = New.outgoingServerName,
                fromName = New.fromName,
                fromAddress = New.fromAddress,
                subject = New.subject,
                returnURLRoot = New.returnURLRoot,
                plainBody = New.plainBody,
                hTMLBody = New.hTMLBody,
                redirectURL = New.redirectURL,
                draft = New.draft,
                revisedAt = now()
        from New
        where id = emailId
        returning Email.*
$$;

