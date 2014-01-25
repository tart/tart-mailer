Begin;

Alter table Email add column draft boolean not null default false;

Create or replace function GetEmail(integer)
    returns Email
    language sql
    as $$
Select * from Email where id = $1
$$;

Commit;

