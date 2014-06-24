Create or replace view NestedEmail as
    with EmailVariations as (select fromAddress, emailId,
                    array_agg(EmailVariation) as variations
                from EmailVariation
                group by fromAddress, emailId)
    select Email.*,
            coalesce(variations, '{}'::EmailVariation[]) as variations
        from Email
            left join EmailVariations using (fromAddress, emailId);

Create or replace function InsertNestedEmail()
    returns trigger
    language plpgsql
    as $$
Begin
    with NewEmail as (insert into Email (fromAddress, emailId, bulk, redirectURL, locale, state)
            values (new.fromAddress, new.emailId, new.bulk, new.redirectURL,
                    coalesce(new.locale, '{}'::LocaleCodeArray), coalesce(new.state, 'new'))
            returning *),
        NewEmailVariation as (insert into EmailVariation (fromAddress, emailId, variationId, subject,
                plainBody, hTMLBody, state)
            select NewEmail.fromAddress, NewEmail.emailId, Variation.variationId, Variation.subject,
                    Variation.plainBody, Variation.hTMLBody, coalesce(Variation.state, 'new')
                from NewEmail,
                        unnest(new.variations) as Variation
            returning *),
        NewEmailVariations as (select fromAddress, emailId,
                    array_agg(NewEmailVariation::EmailVariation) as variations
                from NewEmailVariation
                group by fromAddress, emailId)
            select NewEmail.*,
                    coalesce(variations, '{}'::EmailVariation[]) as variations
                from NewEmail
                    left join NewEmailVariations using (fromAddress, emailId)
        into new;

    return new;
End;
$$;

Create trigger NestedEmailT000 instead of insert on NestedEmail
    for each row
    execute procedure InsertNestedEmail();

Create or replace function HstoreToEmailVariation(hstore)
    returns EmailVariation
    language sql
    as $$
Select populate_record(null::EmailVariation, $1);
$$;

Create cast (hstore as EmailVariation)
    with function HstoreToEmailVariation(hstore) as implicit;

Create or replace view NestedEmailSend as
    with EmailSendFeedbacks as (select fromAddress, toAddress, emailId,
                    array_agg(EmailSendFeedback) as feedbacks
                from EmailSendFeedback
                group by fromAddress, toAddress, emailId),
        EmailSendResponseReports as (select fromAddress, toAddress, emailId,
                    array_agg(EmailSendResponseReport) as responseReports
                from EmailSendResponseReport
                group by fromAddress, toAddress, emailId)
    select EmailSend.*,
            coalesce(feedbacks, '{}'::EmailSendFeedback[]) as feedbacks,
            coalesce(responseReports, '{}'::EmailSendResponseReport[]) as responseReports
        from EmailSend
            left join EmailSendFeedbacks using (fromAddress, toAddress, emailId)
            left join EmailSendResponseReports using (fromAddress, toAddress, emailId);
