Begin;

Create extension if not exists plpythonu;

Create or replace function FormatEmailToSend(body text, k text[], v text[])
    returns text
    language plpythonu strict
    as $$
return body.format(**dict(zip(k, v)))
$$;

Commit;

