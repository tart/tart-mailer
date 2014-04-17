Create extension if not exists plpythonu;

Create or replace function GeneratePassword()
    returns text
    language plpythonu strict
    as $$
import random, string

return ''.join(random.choice(string.ascii_uppercase + string.ascii_lowercase + string.digits) for _ in range(16))
$$;

Alter table Sender add column password varchar(100) not null default GeneratePassword();

Create or replace function SenderAuthenticate(
        username varchar(200),
        password varchar(100)
    ) returns boolean
    language sql strict
    as $$
Select exists(select 1 from Sender where fromAddress = SenderAuthenticate.username
                and  password = SenderAuthenticate.password)
$$;
