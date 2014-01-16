Begin;

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
                        and not exists (select 1 from EmailSend
                                    where EmailSend.emailId = emailId
                                            and EmailSend.subscriberId = Subscriber.id)
        returning *)
    select count(*) from NewEmailSend
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
                        and not exists (select 1 from EmailSend
                                    where EmailSend.emailId = emailId
                                            and EmailSend.subscriberId = Subscriber.id)
                        and not exists (select 1 from EmailSendFeedback as Feedback
                                    where Feedback.subscriberId = Subscriber.id
                                            and Feedback.type = 'unsubscribe')
        limit subscriberCount
        returning *)
    select count(*) from NewEmailSend
$$;

Commit;

