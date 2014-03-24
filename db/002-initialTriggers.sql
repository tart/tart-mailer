Begin;

Create or replace function SetRevisedAt()
    returns trigger
    language plpgsql
    as $$
Begin
    new.revisedAt = now();
    return new;
End;
$$;

Create trigger SubscriberUpdateRevisedAtT before update on Subscriber
    for each row execute procedure SetRevisedAt();

Create trigger EmailVariationUpdateRevisedAtT before update on EmailVariation
    for each row execute procedure SetRevisedAt();

Create trigger EmailSendUpdateRevisedAtT before update on EmailSend
    for each row execute procedure SetRevisedAt();

Create or replace function SetNextEmailId()
    returns trigger
    language plpgsql
    as $$
Begin
    new.emailId = coalesce((select max(emailId) from Email where fromAddress = new.fromAddress), 0) + 1;
    return new;
End;
$$;

Create trigger EmailInsertEmailIdT before insert on Email
    for each row execute procedure SetNextEmailId();

Create or replace function SetNextVariationId()
    returns trigger
    language plpgsql
    as $$
Begin
    new.variationId = (select coalesce(max(variationId), 0) + 1 from EmailVariation
                            where fromAddress = new.fromAddress and emailId = new.emailId);
    return new;
End;
$$;

Create trigger EmailVariationInsertVariationIdT before insert on EmailVariation
    for each row execute procedure SetNextVariationId();

Commit;
