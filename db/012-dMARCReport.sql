Create extension if not exists btree_gist;

Create table DMARCReport (
    reporterAddress EmailAddress not null,
    reportId varchar(200) not null,
    createdAt timestamptz not null default now(),
    domain varchar(200) not null,
    period tstzrange not null,
    body xml not null,
    constraint DMARCReportPK primary key (reporterAddress, reportId),
    constraint DMARCReportPeriodE exclude using gist (reporterAddress with =, domain with =, period with &&)
);

Create type DMARCDisposition as enum (
    'none',
    'quarantine',
    'reject'
);

Create table DMARCReportRow (
    reporterAddress EmailAddress not null,
    reportId varchar(200) not null,
    source inet not null,
    messageCount integer not null,
    disposition DMARCDisposition not null default 'none',
    dKIMPass boolean not null default false,
    sPFPass boolean not null default false,
    constraint DMARCReportRowFK foreign key (reporterAddress, reportId)
            references DMARCReport on delete cascade on update cascade,
    constraint DMARCReportRowMessageCountC check (messageCount > 0)
);

Create or replace view DomainDetail as
    select domain,
            array_agg(distinct reporterAddress::text) as reporterAddresses,
            count(*) as dMARCReports,
            max(createdAt) as lastReport
        from DMARCReport
            group by domain;

Create or replace view DMARCReportDetail as
    select DMARCReport.domain,
            DMARCReport.reporterAddress,
            DMARCReport.reportId,
            DMARCReport.createdAt,
            count(DMARCReportRow) as rows,
            sum(DMARCReportRow.messageCount) as total,
            sum((DMARCReportRow.disposition = 'quarantine')::integer * DMARCReportRow.messageCount) as quarantines,
            sum((DMARCReportRow.disposition = 'reject')::integer * DMARCReportRow.messageCount) as rejects
        from DMARCReport
            left join DMARCReportRow using (reporterAddress, reportId)
            group by DMARCReport.reporterAddress, DMARCReport.reportId
            order by DMARCReport.createdAt;
