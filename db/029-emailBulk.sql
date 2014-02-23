Create or replace function SendBulkEmail(
        emailId integer,
        subscriberCount integer,
        locale text[],
        variation text[]
    ) returns bigint
    language sql
    as $$
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
        order by id
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
            where (select bulk from Email where Email.id = SendBulkEmail.emailId)
        returning *)
    select count(*) from NewEmailSend
$$;
