Create or replace function SetRevisedAt()
    returns trigger
    language plpgsql
    as $$
Begin
    new.revisedAt = now();
    return new;
End;
$$;

Create trigger SubscriberUpdateT000 before update on Subscriber
    for each row execute procedure SetRevisedAt();

Create trigger EmailVariationUpdateT000 before update on EmailVariation
    for each row
    execute procedure SetRevisedAt();

Create trigger EmailSendUpdateT000 before update on EmailSend
    for each row
    execute procedure SetRevisedAt();

Create or replace function SetNextEmailId()
    returns trigger
    language plpgsql
    as $$
Begin
    new.emailId = coalesce((select max(emailId) from Email where fromAddress = new.fromAddress), 0) + 1;
    return new;
End;
$$;

Create trigger EmailInserT000 before insert on Email
    for each row
    when (new.emailId is null)
    execute procedure SetNextEmailId();

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

Create trigger EmailVariationInsertT000 before insert on EmailVariation
    for each row
    when (new.variationId is null)
    execute procedure SetNextVariationId();

Create or replace function SetNameFromEmailId()
    returns trigger
    language plpgsql
    as $$
Begin
    new.name = new.emailId::text || '. Email';
    return new;
End;
$$;

Create trigger EmailInsertT001 before insert on Email
    for each row
    when (new.name is null)
    execute procedure SetNameFromEmailId();

Create or replace function SetFeedbackTypeToSubscriberState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Subscriber
        set state = new.feedbackType
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < new.feedbackType;

    return new;
End;
$$;

Create trigger EmailSendFeedbackInsertT000 before insert on EmailSendFeedback
    for each row
    execute procedure SetFeedbackTypeToSubscriberState();

Create or replace function SetResponseReportToSubscriberState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Subscriber
        set state = 'responseReport'
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < 'responseReport';

    return new;
End;
$$;

Create trigger EmailSendResponseReportInsertT000 before update on EmailSendResponseReport
    for each row
    execute procedure SetResponseReportToSubscriberState();

Create or replace function SetSentToSubscriberState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Subscriber
        set state = 'sent'
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < 'sent';

    return new;
End;
$$;

Create trigger EmailSendUpdateT001 before update on EmailSend
    for each row
    when (new.sent)
    execute procedure SetSentToSubscriberState();
