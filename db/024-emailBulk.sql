Begin;

Alter table Email add column bulk boolean default false;

Update Email set bulk = True
    where id in (select emailId from EmailVariation where not draft);

Drop function if exists SendEmail(integer, integer, text[], text[]);

Commit;
