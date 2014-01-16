Begin;

Create extension if not exists plpythonu;

Create or replace function FormatEmailToSend(body text, k text[], v text[])
    returns text
    language plpythonu strict
    as $$
# Default string.format() function cannot be use is does not support default values.
# See http://bugs.python.org/issue6081

from string import Formatter
from collections import defaultdict

return Formatter().vformat(body, (), defaultdict(str, zip(k, v)))
$$;

Commit;

