-- Multi-tenant model: many organizations share the same tables,
-- and every row belongs to exactly one organization (org_id).

create extension if not exists pgcrypto;

create type member_role as enum ('owner', 'admin', 'member');

create table organizations (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

-- Which user belongs to which organization, and with what role.
create table memberships (
  user_id uuid not null references auth.users (id) on delete cascade,
  org_id  uuid not null references organizations (id) on delete cascade,
  role    member_role not null default 'member',
  primary key (user_id, org_id)
);

-- Example tenant data: projects belong to an organization.
create table projects (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references organizations (id) on delete cascade,
  name       text not null,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);

create index memberships_org_id_idx on memberships (org_id);
create index projects_org_id_idx on projects (org_id);
