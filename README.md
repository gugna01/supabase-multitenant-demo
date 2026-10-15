# supabase-multitenant-demo

A small, readable example of a **multi-tenant** data model in Supabase / PostgreSQL, using Row Level Security (RLS).

> Español: un ejemplo pequeño de modelo **multi-tenant** (multiempresa) en Supabase y PostgreSQL. Varias organizaciones
> comparten las mismas tablas, pero cada una solo ve sus propios datos, porque la propia base de datos aplica las reglas (RLS).

## The idea

In a multi-tenant app, many organizations (tenants) use the same tables. Each row carries an `org_id`, and
database policies make sure a user can only touch rows of the organizations they belong to.

```
organizations ──< memberships >── auth.users      (a user can belong to many organizations, with a role)
      │
      └──< projects                                (tenant data: every row has an org_id)
```

## What is in the repo

| File | What it does |
|---|---|
| `supabase/migrations/001_schema.sql` | Tables: `organizations`, `memberships` (with roles) and `projects`, plus indexes on `org_id` |
| `supabase/migrations/002_rls.sql` | Helper functions `is_org_member` and `has_org_role`, RLS policies, and `create_organization()` which also makes the caller the owner |
| `supabase/tests/isolation_test.sql` | Creates two organizations and checks that user A can not read, insert into or update the data of user B, and the other way round |

## Roles

| Role | Read | Create projects | Edit / delete projects | Manage members |
|---|---|---|---|---|
| `member` | yes | yes | no | no |
| `admin` | yes | yes | yes | yes |
| `owner` | yes | yes | yes | yes |

## How to run it

1. Create a free Supabase project.
2. In the SQL editor, run `001_schema.sql` and then `002_rls.sql`.
3. Run `supabase/tests/isolation_test.sql`. It inserts test users, runs eight checks acting as each user
   (it sets the same JWT claim that the API sets) and rolls everything back. If a check fails, it stops with a message that
   says which one. If all pass, it returns `all isolation checks passed`.

## Honest notes

- The SQL files were syntax-checked with a PostgreSQL parser. **Run the isolation test in your own project to confirm the behavior** before you rely on it.
- `SECURITY DEFINER` helpers are used on purpose, so the policy on `memberships` does not call itself in a loop. They set `search_path` explicitly.
- This is a teaching example: it has no billing, invitations by email, or soft delete.

## License

MIT
