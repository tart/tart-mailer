Begin;

Create extension if not exists hstore;

Create or replace function SubscriberExampleProperties(fromAddress varchar(200))
    returns hstore
    language sql strict
    as $$
With LimitedSubscriber as (select * from Subscriber
        where fromAddress = SubscriberExampleProperties.fromAddress
        limit 1000)
    select properties
        from LimitedSubscriber
            order by array_length(hstore_to_array(properties), 1) * random()
                limit 1
$$;

Commit;
