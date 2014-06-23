Create or replace function textregexreveq(text, text)
    returns boolean
    language sql
    as 'select textregexeq($2, $1)';

Create operator ^~ (
    procedure = textregexreveq,
    leftarg = text,
    rightarg = text
);
