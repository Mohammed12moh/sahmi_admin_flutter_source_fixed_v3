-- Sahmi Admin bootstrap schema for Supabase PostgreSQL.
-- Review against the existing Sahmi schema before applying. It does not modify existing financial tables.
-- Bootstrap the first Super Admin manually in Supabase SQL Editor after creating the auth user.
-- Never allow client apps to assign their own roles.

begin;

create table if not exists public.admin_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  role text not null check (role in ('super_admin','admin','moderator','support')),
  permissions jsonb not null default '[]'::jsonb check (jsonb_typeof(permissions) = 'array'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_type text,
  target_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.admin_notification_queue (
  id bigint generated always as identity primary key,
  title text not null,
  body text not null,
  audience text not null default 'all',
  status text not null default 'queued' check (status in ('queued','processing','sent','failed')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  error_message text
);

create or replace function public.is_active_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_members m
    where m.user_id = (select auth.uid())
      and m.is_active = true
  );
$$;

create or replace function public.has_admin_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_members m
    where m.user_id = (select auth.uid())
      and m.is_active = true
      and m.role = any(required_roles)
  );
$$;

alter table public.admin_members enable row level security;
alter table public.admin_audit_log enable row level security;
alter table public.admin_notification_queue enable row level security;

drop policy if exists "admin read team" on public.admin_members;
create policy "admin read team" on public.admin_members
for select to authenticated using (public.is_active_admin());

drop policy if exists "admin read audit" on public.admin_audit_log;
create policy "admin read audit" on public.admin_audit_log
for select to authenticated using (public.is_active_admin());

drop policy if exists "admin read notification queue" on public.admin_notification_queue;
create policy "admin read notification queue" on public.admin_notification_queue
for select to authenticated using (public.has_admin_role(array['super_admin','admin']));

drop policy if exists "admin queue notifications" on public.admin_notification_queue;
create policy "admin queue notifications" on public.admin_notification_queue
for insert to authenticated
with check (
  public.has_admin_role(array['super_admin','admin'])
  and created_by = (select auth.uid())
  and status = 'queued'
);

revoke all on function public.is_active_admin() from public, anon;
revoke all on function public.has_admin_role(text[]) from public, anon;
grant execute on function public.is_active_admin() to authenticated;
grant execute on function public.has_admin_role(text[]) to authenticated;

grant select on public.admin_members, public.admin_audit_log to authenticated;
grant select, insert on public.admin_notification_queue to authenticated;
revoke update, delete on public.admin_members from anon, authenticated;
revoke insert, update, delete on public.admin_audit_log from anon, authenticated;

-- IMPORTANT: Set the first Super Admin only after confirming the correct auth.users UUID.
-- Replace the UUID and email below; run manually as database owner, not from the app.
-- insert into public.admin_members(user_id,email,role,permissions)
-- values ('REPLACE-WITH-AUTH-USER-UUID','admin@example.com','super_admin','["*"]'::jsonb);

commit;
