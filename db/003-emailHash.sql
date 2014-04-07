Create extension if not exists pgcrypto;

Create or replace function Base64ForURL(bytea)
    returns text
    language sql strict
    as $$
-- Replace characters according to RFC 4648
-- See: http://tools.ietf.org/html/rfc4648#page-7
Select replace(replace(replace(encode($1, 'base64'), '+', '-'), '/', '_'), '=', '')
$$;

Create or replace function EmailHash(EmailSend)
    returns text
    language sql strict
    as $$
Select Base64ForURL(digest('secret1' || $1.fromAddress ||
                           'secret2' || $1.toAddress ||
                           'secret3' || to_hex($1.emailId::integer) ||
                           'secret4' || to_hex($1.variationId::integer) ||
                           'secret5', 'sha256'))
$$;

Create unique index EmailSendEmailHashI on EmailSend (EmailHash(EmailSend));
