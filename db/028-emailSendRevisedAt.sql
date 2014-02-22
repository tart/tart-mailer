Begin;

Alter table EmailSend add column revisedAt timestamptz;
Alter table EmailSend alter column revisedAt set default now();

With EmailSendWithRevisedAt as (select EmailSend.emailId, EmailSend.subscriberId,
                    max(greatest(Email.createdAt, EmailSendFeedback.createdAt, EmailSendResponseReport.createdAt))
                            over (partition by EmailSend.emailId order by EmailSend.subscriberId) as revisedAt
                from EmailSend
                    join Email on EmailSend.emailId = Email.id
                    left join EmailSendFeedback on EmailSendFeedback.emailId = EmailSend.emailId
                            and EmailSendFeedback.subscriberId = EmailSend.subscriberId
                    left join EmailSendResponseReport on EmailSendResponseReport.emailId = EmailSend.emailId
                            and EmailSendResponseReport.subscriberId = EmailSend.subscriberId)
    update EmailSend
        set revisedAt = EmailSendWithRevisedAt.revisedAt
        from EmailSendWithRevisedAt
        where EmailSend.revisedAt is null
                and EmailSendWithRevisedAt.emailId = EmailSend.emailId
                and EmailSendWithRevisedAt.subscriberId = EmailSend.subscriberId;

Alter table EmailSend alter column revisedAt set not null; 

Create or replace function SetRevisedAt()
    returns trigger
    language plpgsql
    as $$
Begin
    new.revisedAt = now();
    return new;
End;
$$;

Create trigger EmailVariationUpdateRevisedAtT before update on EmailVariation
    for each row execute procedure SetRevisedAt();

Create trigger SubscriberUpdateRevisedAtT before update on Subscriber
    for each row execute procedure SetRevisedAt();

Create trigger EmailSendUpdateRevisedAtT before update on EmailSend
    for each row execute procedure SetRevisedAt();

Create or replace function SendBulkEmail(
        emailId integer,
        subscriberCount integer,
        locale text[],
        variation text[]
    ) returns bigint
    language sql
    as $$
Update Email
    set bulk = true
    where id = SendBulkEmail.emailId
            and not bulk;
Update EmailVariation
    set draft = false
    where EmailVariation.emailId = SendBulkEmail.emailId
            and EmailVariation.rank = any(SendBulkEmail.variation::smallint[])
            and draft;
With SubscriberWithRowNumber as (select *, row_number() over (order by id) as rowNumber
        from Subscriber
            where exists (select 1 from unnest(SendBulkEmail.locale) as locale
                            where locale is not distinct from Subscriber.locale)
                    and not exists (select 1 from EmailSend
                                where EmailSend.emailId = SendBulkEmail.emailId
                                        and EmailSend.subscriberId = Subscriber.id)
                    and not exists (select 1 from EmailSendFeedback as Feedback
                                where Feedback.subscriberId = Subscriber.id
                                        and Feedback.type = 'unsubscribe')
                    and not exists (select 1 from EmailSendResponseReport as ResponseReport
                                where ResponseReport.subscriberId = Subscriber.id)
        limit SendBulkEmail.subscriberCount),
    EmailVariationWithRowNumber as (select *,
            row_number() over (order by rank) as rowNumber,
            count(*) over () as count
        from EmailVariation
            where EmailVariation.emailId = SendBulkEmail.emailId
                    and EmailVariation.rank = any(SendBulkEmail.variation::smallint[])),
    NewEmailSend as (insert into EmailSend (emailId, subscriberId, variationRank)
        select SendBulkEmail.emailId, S.id, E.rank
            from SubscriberWithRowNumber as S
                join EmailVariationWithRowNumber as E on (S.rowNumber - 1) % E.count = E.rowNumber - 1
        returning *)
    select count(*) from NewEmailSend
$$;

Commit;
