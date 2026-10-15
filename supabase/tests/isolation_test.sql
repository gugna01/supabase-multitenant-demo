-- Isolation test. Run it in the Supabase SQL editor after applying the two migrations.
-- It creates two organizations with one user each, then checks that nobody can see
-- or change the other organization's data. Everything is rolled back at the end.
--
-- If a check fails, the script stops with an exception that says which one.

begin;

-- Fixed ids so the test is readable.
-- user A -> org A      user B -> org B
insert into auth.users (id, aud, role, email)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'a@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'b@example.com');

insert into organizations (id, name)
values
  ('a0a0a0a0-0000-0000-0000-00000000000a', 'Org A'),
  ('b0b0b0b0-0000-0000-0000-00000000000b', 'Org B');

insert into memberships (user_id, org_id, role)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'a0a0a0a0-0000-0000-0000-00000000000a', 'owner'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'b0b0b0b0-0000-0000-0000-00000000000b', 'owner');

insert into projects (org_id, name)
values
  ('a0a0a0a0-0000-0000-0000-00000000000a', 'Project of A'),
  ('b0b0b0b0-0000-0000-0000-00000000000b', 'Project of B');

-- Act as user A (the same thing the API does with a login token).
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"aaaaaaaa-0000-0000-0000-000000000001","role":"authenticated"}', true);

do $$
declare
  n int;
begin
  -- 1. A sees only A's project.
  select count(*) into n from projects;
  assert n = 1, 'check 1 failed: user A should see exactly 1 project, saw ' || n;

  select count(*) into n from projects where name = 'Project of B';
  assert n = 0, 'check 2 failed: user A can see the project of B';

  -- 2. A sees only A's organization.
  select count(*) into n from organizations;
  assert n = 1, 'check 3 failed: user A should see exactly 1 organization, saw ' || n;

  -- 3. A cannot insert a project into B's organization.
  begin
    insert into projects (org_id, name) values ('b0b0b0b0-0000-0000-0000-00000000000b', 'intruder');
    raise exception 'check 4 failed: user A could insert into the organization of B';
  exception when insufficient_privilege or check_violation then
    null; -- expected: the policy blocked it
  end;

  -- 4. A cannot change B's data (the update simply matches no rows).
  update projects set name = 'hacked' where org_id = 'b0b0b0b0-0000-0000-0000-00000000000b';
  get diagnostics n = row_count;
  assert n = 0, 'check 5 failed: user A updated rows of B';

  -- 5. A can insert into A's own organization.
  insert into projects (org_id, name) values ('a0a0a0a0-0000-0000-0000-00000000000a', 'second project of A');
  select count(*) into n from projects;
  assert n = 2, 'check 6 failed: user A should now see 2 projects, saw ' || n;
end $$;

-- Switch to user B and check the mirror image.
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-0000-0000-0000-000000000002","role":"authenticated"}', true);

do $$
declare
  n int;
begin
  select count(*) into n from projects;
  assert n = 1, 'check 7 failed: user B should see exactly 1 project, saw ' || n;
  select count(*) into n from projects where name like '%A%' and name <> 'Project of B';
  assert n = 0, 'check 8 failed: user B can see projects of A';
end $$;

rollback;
select 'all isolation checks passed' as result;
