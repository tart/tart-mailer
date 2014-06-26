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

Create or replace function SetFeedbackTypeToSubscriberState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Subscriber
        set state = new.feedbackType
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < new.feedbackType::SubscriberState;

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

Create or replace function SetStateToEmail()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Email
        set state = new.state
        where fromAddress = new.fromAddress
                and emailId = new.emailId
                and state < new.state;

    return new;
End;
$$;

Create trigger EmailVariationInsertT001 before insert on EmailVariation
    for each row
    when (new.state > 'new')
    execute procedure SetStateToEmail();

Create trigger EmailVariationUpdateT001 before update on EmailVariation
    for each row
    when (new.state > old.state)
    execute procedure SetStateToEmail();
