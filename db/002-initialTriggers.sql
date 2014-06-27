/*
 * Triggers to maintain the revisedAt columns
 *
 * The function sets now() to the revisedAt columns of the following tables. Note that it cannot be overriden but
 * it can be set as something else on insert.
 */

Create or replace function SetRevisedAt()
    returns trigger
    language plpgsql
    as $$
Begin
    new.revisedAt = now();
    return new;
End;
$$;

Create trigger SubscriberSetReviseAtT before update on Subscriber
    for each row
    execute procedure SetRevisedAt();

Create trigger EmailVariationSetRevisedAtT before update on EmailVariation
    for each row
    execute procedure SetRevisedAt();

Create trigger EmailSendSetRevisedAtT before update on EmailSend
    for each row
    execute procedure SetRevisedAt();


/*
 * Trigger to set the variationId column
 *
 * It is not as save and as efficient as using a sequence, but it is not option in here because the variationId
 * column depends on the emailId column. The emailId references the Email table. It comes from a sequence to
 * the Email table.
 */

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

Create trigger EmailVariationDefaultVariationIdT before insert on EmailVariation
    for each row
    when (new.variationId is null)
    execute procedure SetNextVariationId();


/*
 * Triggers to maintain the state column of the Subscriber table
 *
 * The state column of the Subscriber table is not meant to be set manually. It is added for performance of queries
 * which filter subscribers. Updates and inserts on the EmailSend tables will maintain the values on the Subscribers.
 * It should not be a performance problem because all of these operations should be done in the background by
 * the workers. Note that is is restricted to update the state column of the Subscriber table manually. If can used
 * update some subscribers who might complain outside the application.
 */

Create or replace function SetSubscriberState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update Subscriber
        set state = new.state
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < new.state;

    return new;
End;
$$;

Create trigger EmailSendSetSubscriberStateOnInsertT before insert on EmailSend
    for each row
    when (new.state > 'new')
    execute procedure SetSubscriberState();

Create trigger EmailSendSetSubscriberStateOnUpdateT before update on EmailSend
    for each row
    when (new.state > old.state)
    execute procedure SetSubscriberState();


/*
 * Triggers to maintain the state column of the EmailSend table
 *
 * Values higher than 'sent' on the state column of the EmailSend table, are not really required for anything except
 * the statistics views. These will be set by the following triggers. It will also cause the state column of
 * the Subscriber table to be updated.
 */

Create or replace function SetEmailSendResponseReportState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update EmailSend
        set state = 'responseReport'
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state = 'sent';

    return new;
End;
$$;

Create trigger EmailSendResponseReportSetEmailSendResponseReportStateT before insert on EmailSendResponseReport
    for each row
    execute procedure SetEmailSendResponseReportState();

Create or replace function SetEmailSendFeedbackState()
    returns trigger
    language plpgsql
    as $$
Begin
    Update EmailSend
        set state = new.state
        where fromAddress = new.fromAddress
                and toAddress = new.toAddress
                and state < new.state;

    return new;
End;
$$;

Create trigger EmailSendFeedbackSetEmailSendFeedbackStateT before insert on EmailSendFeedback
    for each row
    execute procedure SetEmailSendFeedbackState();


/*
 * Triggers to maintain state column of the Email table
 *
 * The state column of the Email table is used on its own, but it must be more restricted than all of the states of
 * its variations. Following insert and update triggers will satisfy this by not raising any errors.
 */

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

Create trigger EmailVariationSetEmailStateOnInsertT before insert on EmailVariation
    for each row
    when (new.state > 'new')
    execute procedure SetStateToEmail();

Create trigger EmailVariationSetEmailStateOnUpdateT before update on EmailVariation
    for each row
    when (new.state > old.state)
    execute procedure SetStateToEmail();


/*
 * Trigger to reset the sendOrder columns
 *
 * It is done to save some space.
 */

Create or replace function ResetSendOrder()
    returns trigger
    language plpgsql
    as $$
Begin
    new.sendOrder = null;
    return new;
End;
$$;

Create trigger EmailSendResetSendOrderT before update on EmailSend
    for each row
    when (new.state > 'new' and new.sendOrder is not null)
    execute procedure ResetSendOrder();
