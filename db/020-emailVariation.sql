Begin;

Create table EmailVariation (
    emailId integer not null,
    rank smallint not null,
    subject varchar(1000) not null,
    plainBody text,
    hTMLBody text,
    draft boolean not null default true,
    revisedAt timestamptz not null default now(),
    constraint EmailVariationPK primary key (emailId, rank),
    constraint EmailVariationRankC check (rank >= 0),
    constraint EmailVariationBodyC check (((plainBody is not null) or (hTMLBody is not null)))
);

Create or replace function SetNextEmailVariationRank()
    returns trigger
    language plpgsql
    as $$
Begin
    new.rank = (select coalesce(max(EmailVariation.rank), 0) + 1 from EmailVariation where emailId = new.emailId);
    return new;
End;
$$;

Create trigger EmailVariationInsertRankT before insert on EmailVariation
    for each row execute procedure SetNextEmailVariationRank();

Alter table EmailSend
    add column variationRank smallint,
    add constraint EmailSendVariationRankFK foreign key (emailId, variationRank)
            references EmailVariation (emailId, rank);

Insert into EmailVariation
    select id, 1, subject, plainBody, hTMLBody, false, revisedAt from Email;

Update EmailSend set variationRank = 1;

Alter table Email 
    drop constraint EmailBodyC,
    drop constraint EmailRevisedAtC,
    drop column subject,
    drop column plainBody,
    drop column hTMLBody,
    drop column revisedAt;

Alter table EmailSend
    drop constraint EmailSendFK,
    alter column variationRank set not null;

Drop function if exists RemoveTestEmailSend(integer);

Drop function if exists SendTestEmail(integer, varchar(200));

Create or replace function SendTestEmail(
        emailId integer,
        variationRank integer,
        emailAddress varchar(200)
    ) returns boolean
    language sql
    as $$
With UpdatedEmailSend as (update EmailSend
            set sent = false,
                    variationRank = variationRank
            from Subscriber
                where Subscriber.emailAddress = SendTestEmail.emailAddress
                        and EmailSend.emailId = SendTestEmail.emailId
                        and EmailSend.subscriberId = Subscriber.id
            returning true),
    InsertedEmailSend as (insert into EmailSend (emailId, subscriberId, variationRank)
            select SendTestEmail.emailId, Subscriber.id, SendTestEmail.variationRank
                from Subscriber
                    where Subscriber.emailAddress = SendTestEmail.emailAddress
                            and not exists (select true
                                        from EmailSend
                                            where EmailSend.emailId = SendTestEmail.emailId
                                                    and EmailSend.subscriberId = Subscriber.id)
            returning true)
    select coalesce((select * from UpdatedEmailSend),
                    (select * from InsertedEmailSend))
$$;

Create or replace function EmailVariationStats(integer)
    returns table (
        variation smallint,
        send bigint
    )
    language sql
    as $$
Select EmailVariation.rank, coalesce(count(EmailSend), 0)
    from EmailVariation
        left join EmailSend on EmailSend.emailId = EmailVariation.emailId
                and EmailSend.variationRank = EmailVariation.rank
        where EmailVariation.emailId = $1
        group by EmailVariation.rank
        order by EmailVariation.rank
$$;

Drop function if exists SendEmail(integer, integer, char(5)[]);

Commit;
