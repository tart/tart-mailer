Begin;

Create extension if not exists hstore;

Create or replace function SubscriberExampleProperties()
    returns hstore
    language sql
    as $$
Select properties
    from (select * from Subscriber limit 1000) as Subscriber
        order by array_length(hstore_to_array(properties), 1) * random()
            limit 1
$$;

Commit;

