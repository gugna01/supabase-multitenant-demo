-- Row Level Security: the database itself decides which rows a user can see.

-- Helper functions. SECURITY DEFINER lets the policies read "memberships"
-- without the policy on "memberships" calling itself in a loop.
create or replace function is_org_member(target_org uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from memberships m
    where m.org_id = target_org
      and m.user_id = auth.uid()
  );
$$;

create or replace function has_org_role(target_org uuid, allowed member_role[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from memberships m
    where m.org_id = target_org
      and m.user_id = auth.uid()
      and m.role = any (allowed)
  );
$$;

alter table organizations enable row level security;
alter table memberships   enable row level security;
alter table projects      enable row level security;

-- organizations: you only see the organizations you belong to.
create policy organizations_select on organizations
  for select using (is_org_member(id));

-- memberships: members can see who is in their organization;
-- only owners and admins can add, change or remove members.
create policy memberships_select on memberships
  for select using (is_org_member(org_id));

create policy memberships_write on memberships
  for all
  using (has_org_role(org_id, array['owner', 'admin']::member_role[]))
  with check (has_org_role(org_id, array['owner', 'admin']::member_role[]));

-- projects: members read and create; only owners and admins edit or delete.
create policy projects_select on projects
  for select using (is_org_member(org_id));

create policy projects_insert on projects
  for insert with check (is_org_member(org_id));

create policy projects_update on projects
  for update
  using (has_org_role(org_id, array['owner', 'admin']::member_role[]))
  with check (has_org_role(org_id, array['owner', 'admin']::member_role[]));

create policy projects_delete on projects
  for delete using (has_org_role(org_id, array['owner', 'admin']::member_role[]));

-- Creating an organization: a function that also makes the caller its owner.
create or replace function create_organization(org_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  insert into organizations (name) values (org_name) returning id into new_org;
  insert into memberships (user_id, org_id, role) values (auth.uid(), new_org, 'owner');
  return new_org;
end;
$$;
