Begin;

Create extension if not exists hstore;

Create or replace function SubscriberExampleProperties()
    returns hstore
    language sql
    as $$
Select properties
    from Subscriber 
        order by array_length(hstore_to_array(properties), 1) * random()
            limit 1
$$;

Create or replace function SubscriberLocaleStats(integer)
    returns table (
        locale char(5),
        count bigint,
        sendCount bigint
    )
    language sql
    as $$
Select Subscriber.locale, count(*) as count, count(EmailSend) as sendCount
    from Subscriber
        left join EmailSend on EmailSend.subscriberId = Subscriber.id
                and EmailSend.emailId = $1
        where not exists (select 1 from EmailSendFeedback as Feedback
                    where Feedback.subscriberId = Subscriber.id
                            and Feedback.type = 'unsubscribe')
        group by Subscriber.locale
$$;

Commit;

