Begin;

Create extension if not exists hstore;

Create or replace function SubscriberInfo()
    returns table (
        maxSubscriberId integer,
        subscriberCount bigint,
        exampleProperties hstore
    )
    language sql
    as $$
With Stats as (select max(id) as maxSubscriberId, count(*) as subscriberCount
        from Subscriber where status = 'subscribed')
    select Stats.maxSubscriberId, Stats.subscriberCount, Subscriber.properties
        from Stats
            join Subscriber on id > random() * Stats.maxSubscriberId
                    and (properties != ''::hstore or Subscriber.id = Stats.maxSubscriberId)
            order by Subscriber.id
                limit 1
$$;

Create or replace function NewEmail(
        fromName varchar(200),
        fromAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        returnURLRoot varchar(1000),
        redirectURL varchar(1000),
        maxSubscriberId integer
    ) returns table (
        subscriberCount bigint
    )
    language sql
    as $$
With NewEmail as (insert into email (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL) values
        (fromName, fromAddress, subject, plainBody, hTMLBody, returnURLRoot, redirectURL)
        returning *),
    NewEmailSent as (insert into EmailSend (emailId, subscriberId)
        select NewEmail.id, Subscriber.id
            from NewEmail, Subscriber
                where Subscriber.id <= maxSubscriberId and Subscriber.status = 'subscribed'
        returning *)
    select count(*) from NewEmailSent
$$;

Commit;

