Begin;

Drop function if exists NewEmailSendResponseReport(varchar, hstore, hstore, text);

Create or replace function LastEmailSendToEmailAddresses(projectName varchar(200), emailAddresses varchar(200)[])
    returns setof EmailSend
    language sql
    as $$
Select EmailSend.*
    from Email
        join EmailSend on EmailSend.emailId = Email.id
                and EmailSend.sent
            join Subscriber on EmailSend.subscriberId = Subscriber.id
                    and Subscriber.emailAddress = any(LastEmailSendToEmailAddresses.emailAddresses)
        where LastEmailSendToEmailAddresses.projectName is null
                or Email.projectName = LastEmailSendToEmailAddresses.projectName
        order by EmailSend.revisedAt desc
            limit 1
$$;

Commit;
