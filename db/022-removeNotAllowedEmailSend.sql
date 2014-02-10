Create or replace function RemoveNotAllowedEmailSend(outgoingServerName varchar(200))
    returns setof EmailSend
    language sql
    as $$
Delete from EmailSend
    where emailId in (select id from Email where outgoingServerName = RemoveNotAllowedEmailSend.outgoingServerName)
            and not sent
            and (subscriberId in (select subscriberId from EmailSendFeedback where type = 'unsubscribe')
                    or subscriberId in (select subscriberId from EmailSendResponseReport))
    returning *
$$;
