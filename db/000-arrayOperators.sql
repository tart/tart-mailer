/*
 * Operators for arrays
 *
 * These operators are created to be used with any/some/all (array expresion).
 */

Create or replace function textregexreveq(text, text)
    returns boolean
    language sql
    as 'select textregexeq($2, $1)';

Create operator ^~ (
    procedure = textregexreveq,
    leftarg = text,
    rightarg = text
);

Create or replace function isNotDistinctFrom(anyelement, anyelement)
    returns boolean
    language sql
    as 'select $1 is not distinct from $2';

Create operator == (
    procedure = isNotDistinctFrom,
    leftarg = anyelement,
    rightarg = anyelement
);

Create or replace function isDistinctFrom(anyelement, anyelement)
    returns boolean
    language sql
    as 'select $1 is distinct from $2';

Create operator !== (
    procedure = isDistinctFrom,
    leftarg = anyelement,
    rightarg = anyelement
);
