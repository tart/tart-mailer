Create domain Name varchar(200)
    constraint NameC check (length(value) > 2);

Alter table Email
    add column name Name;

Update Email set name = emailId::text || '. Email';

Alter table Email
    alter column name set not null,
    add constraint EmailNameUK unique (name, fromAddress);

Alter trigger SubscriberUpdateRevisedAtT on Subscriber rename to SubscriberUpdateT000;

Alter trigger EmailVariationUpdateRevisedAtT on EmailVariation rename to EmailVariationUpdateT000;

Alter trigger EmailSendUpdateRevisedAtT on EmailSend rename to EmailSendUpdateT000;

Alter trigger EmailInsertEmailIdT on Email rename to EmailInsertT000;

Alter trigger EmailVariationInsertVariationIdT on EmailVariation rename to EmailVariationInsertT000;

Alter trigger NestedEmailInsertT on NestedEmail rename to NestedEmailT;

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

Create or replace view EmailStatistics as
    with EmailVariationStats as (select fromAddress, emailId, count(*) as count
            from EmailVariation
            group by fromAddress, emailId),
        EmailSendStats as (select fromAddress, emailId, count(*) as totalCount, sum(sent::int) as sentCount
            from EmailSend
            group by fromAddress, emailId),
        EmailSendResponseReportStats as (select fromAddress, emailId, count(*) as count
            from EmailSendResponseReport
            group by fromAddress, emailId),
        EmailSendFeedbackStats as (select fromAddress, emailId,
                sum((feedbackType = 'trackerImage')::int) as trackerImageCount,
                sum((feedbackType = 'view')::int) as viewCount,
                sum((feedbackType = 'redirect')::int) as redirectCount,
                sum((feedbackType = 'unsubscribe')::int) as unsubscribeCount
            from EmailSendFeedback
            group by fromAddress, emailId)
        select Email.fromAddress,
                Email.emailId,
                Email.name,
                Email.createdAt,
                Email.bulk,
                coalesce(EmailVariationStats.count, 0) as variations,
                coalesce(EmailSendStats.totalCount, 0) as totalMessages,
                coalesce(EmailSendStats.sentCount, 0) as sentMessages,
                coalesce(EmailSendResponseReportStats.count, 0) as responseReports,
                coalesce(EmailSendFeedbackStats.trackerImageCount, 0) as trackerImages,
                coalesce(EmailSendFeedbackStats.viewCount, 0) as views,
                coalesce(EmailSendFeedbackStats.redirectCount, 0) as redirects,
                coalesce(EmailSendFeedbackStats.unsubscribeCount, 0) as unsubscribes
            from Email
                left join EmailVariationStats using (fromAddress, emailId)
                left join EmailSendStats using (fromAddress, emailId)
                left join EmailSendResponseReportStats using (fromAddress, emailId)
                left join EmailSendFeedbackStats using (fromAddress, emailId)
                order by Email.fromAddress, Email.emailId;
