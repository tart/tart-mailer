Create or replace function LastEmailSendToEmailAddresses(toAddresses varchar(200)[])
    returns setof EmailSend
    language sql strict
    as $$
Select *
    from EmailSend
        where state = 'sent'
                and toAddress = any(toAddresses)
        order by revisedAt desc
            limit 1
$$;

Create or replace function LastEmailSendToEmailAddresses(fromAddress varchar(200), toAddresses varchar(200)[])
    returns setof EmailSend
    language sql strict
    as $$
Select *
    from EmailSend
        where state = 'sent'
                and fromAddress = LastEmailSendToEmailAddresses.fromAddress
                and toAddress = any(toAddresses)
        order by revisedAt desc
            limit 1
$$;

Create or replace function EmailSendFromUnsubscribeURL(unsubscribeURL text)
    returns setof EmailSend
    language sql strict
    as $$
select EmailSend.*
    from EmailSend
        join Sender using (fromAddress)
        where EmailSend.state = 'sent'
                and MessageHash(EmailSend) = regexp_replace(EmailSendFromUnsubscribeURL.unsubscribeURL,
                                                            '^' || Sender.returnURLRoot || 'unsubscribe/', '')
$$;

Create or replace function EmailSendFromUnsubscribeURL(fromAddress varchar(200), unsubscribeURL text)
    returns setof EmailSend
    language sql strict
    as $$
select EmailSend.*
    from EmailSend
        join Sender using (fromAddress)
        where EmailSend.state = 'sent'
                and EmailSend.fromAddress = EmailSendFromUnsubscribeURL.fromAddress
                and MessageHash(EmailSend) = regexp_replace(EmailSendFromUnsubscribeURL.unsubscribeURL,
                                                            '^' || Sender.returnURLRoot || 'unsubscribe/', '')
$$;
