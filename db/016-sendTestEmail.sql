Begin;

Drop function if exists RemoveTestEmailSend(integer);

Drop function if exists SendTestEmail(integer, varchar(200));

Create or replace function SendTestEmail(
        emailId integer,
        subscriberEmailAddress varchar(200)
    ) returns boolean
    language sql
    as $$
With NewEmailSend as (select emailId, Subscriber.id as subscriberId
            from Subscriber
                where Subscriber.emailAddress = subscriberEmailAddress),
    UpdatedEmailSend as (update EmailSend set sent = false
            from NewEmailSend
                where EmailSend.emailId = NewEmailSend.emailId
                        and EmailSend.subscriberId = NewEmailSend.subscriberId
                        and EmailSend.sent
            returning true),
    InsertedEmailSend as (insert into EmailSend (emailId, subscriberId)
            select *
                from NewEmailSend
                    where not exists (select true
                        from EmailSend
                            where EmailSend.emailId = NewEmailSend.emailId
                                    and EmailSend.subscriberId = NewEmailSend.subscriberId)
            returning true)
    select coalesce((select * from UpdatedEmailSend),
                    (select * from InsertedEmailSend))
$$;

Commit;

