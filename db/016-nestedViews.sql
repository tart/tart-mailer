/*
 * NestedEmail view for the API
 *
 * The view supplies nested email documents to the API. Update and insert function will be added by "instead of"
 * triggers. Cast from hstore to EmailVariation is also required, because the API does not know about the custom
 * types on the database. Hstore is the registered typed of the API for allkinds of dictionary structures. It will
 * be handled by the implicit cast.
 */

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
    with NewEmail as (insert into Email (fromAddress, emailId, bulk, redirectURL, name, locale, state)
            values (
                    new.fromAddress,
                    coalesce(new.emailId, nextval('EmailId'::regclass)),
                    new.bulk,
                    new.redirectURL,
                    coalesce(new.name, new.emailId || '. Email', currval('EmailId'::regclass) || '. Email'),
                    coalesce(new.locale, '{C}'::LocaleCodeArray),
                    coalesce(new.state, 'new')
            ) returning *),
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

Create trigger NestedEmailInsertT instead of insert on NestedEmail
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
