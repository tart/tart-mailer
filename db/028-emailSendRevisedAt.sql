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

Commit;
