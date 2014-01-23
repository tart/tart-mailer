Begin;

Drop function if exists SendEmail(integer, integer, char(5)[]);

Create or replace function SendEmail(
        emailId integer,
        subscriberCount integer,
        locales char(5)[]
    ) returns bigint
    language sql
    as $$
With RevisedEmail as (update Email set revisedAt = now(), draft = false where id = emailId returning *),
    NewEmailSend as (insert into EmailSend (emailId, subscriberId)
        select RevisedEmail.id, Subscriber.id
            from RevisedEmail, Subscriber
                where exists (select 1 from unnest(locales) as locale
                                where locale is not distinct from Subscriber.locale)
                        and not exists (select 1 from EmailSend
                                    where EmailSend.emailId = RevisedEmail.id
                                            and EmailSend.subscriberId = Subscriber.id)
                        and not exists (select 1 from EmailSendFeedback as Feedback
                                    where Feedback.subscriberId = Subscriber.id
                                            and Feedback.type = 'unsubscribe')
        limit subscriberCount
        returning *)
    select count(*) from NewEmailSend
$$;

Commit;

