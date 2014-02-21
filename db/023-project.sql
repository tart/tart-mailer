Begin;

Create domain EmailAddress varchar(200) collate "C" not null
    constraint EmailAddressC check (value ~ '^[^@]+@[^@]+\.[^@]+$');

Create table Project (
    name varchar(200) not null,
    fromName varchar(200) not null,
    emailAddress EmailAddress,
    returnURLRoot varchar(200) not null,
    createdAt timestamptz not null default now(),
    constraint ProjectPK primary key (name),
    constraint ProjectEmailAddressUK unique (emailAddress)
);

Alter table Email
    add column projectName varchar(200),
    add constraint EmailProjectNameFK foreign key (projectName) references Project (name)
            on update cascade;

Alter table Subscriber
    drop constraint SubscriberEmailAddressC,
    alter column emailAddress type emailAddress,
    add column projectName varchar(200),
    add constraint SubscriberProjectNameFK foreign key (projectName) references Project (name)
            on update cascade;

Insert into Project (name, fromName, emailAddress, returnURLRoot, createdAt)
    select fromAddress, min(fromName), fromAddress, min(returnURLRoot), min(createdAt)
        from Email
        group by fromAddress;

Update Email set projectName = fromAddress;

Update Subscriber
    set projectName = Email.projectName
    from Email
    where Email.id = (select emailId from EmailSend
                    where EmailSend.subscriberId = Subscriber.id
                    group by emailId
                    order by count(*) desc
                    limit 1);

Update Subscriber
    set projectName = Email.projectName
    from Email
    where Subscriber.projectName is null
            and Email.id = (select emailId from EmailSend
                            group by emailId
                            order by count(*) desc
                            limit 1);

Create or replace view ProjectDetail as
    with SubscriberStats as (select projectName, count(*) as count
                    from Subscriber
                    group by projectName),
        EmailStats as (select projectName, count(*) as count
                    from Email
                    group by projectName)
        select Project.name, Project.fromName, Project.emailAddress, Project.returnURLRoot, Project.createdAt,
                coalesce(SubscriberStats.count, 0) as subscribers,
                coalesce(EmailStats.count, 0) as emails
            from Project
                left join SubscriberStats on SubscriberStats.projectName = Project.name
                left join EmailStats on EmailStats.projectName = Project.name
                order by Project.name;

Drop view if exists EmailDetail;

Alter table Email
    alter column projectName set not null,
    drop column fromName,
    drop column fromAddress,
    drop column returnURLRoot;

Alter table Subscriber
    alter column projectName set not null;

Commit;
