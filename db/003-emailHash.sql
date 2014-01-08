Begin;

Create extension if not exists pgcrypto;

Create or replace function EmailHash(EmailSend)
    returns text
    language sql
    as $$
Select replace(replace(replace(encode(digest('secret' || to_hex($1.emailId) || '&' || to_hex($1.subscriberId) ||
                                                         'anotherSecret',
                                             'sha256'),
                                      'base64'),
                               '+', ''),
                       '/', ''),
               '=', '')
$$;

Create unique index EmailSendEmailHashI on EmailSend (EmailHash(EmailSend));

Commit;

