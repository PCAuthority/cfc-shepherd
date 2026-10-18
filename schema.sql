-- =====================================================================
-- CFC Household Shepherd — Supabase database setup
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Safe to run once on a new project.
-- =====================================================================

-- ---------- 1. Leader profiles ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text not null default '',
  role text not null default 'pending'
    check (role in ('pending','household','unit','chapter')),
  unit text not null default '',
  created_at timestamptz not null default now()
);

-- Helper functions (security definer so policies don't loop on profiles)
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.my_unit() returns text
language sql stable security definer set search_path = public as $$
  select unit from public.profiles where id = auth.uid()
$$;

create or replace function public.unit_of(u uuid) returns text
language sql stable security definer set search_path = public as $$
  select unit from public.profiles where id = u
$$;

-- Can the current leader oversee this person? (Chapter: everyone. Unit: same unit.)
create or replace function public.oversees(u uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select case
    when public.my_role() = 'chapter' then true
    when public.my_role() = 'unit'
         and coalesce(public.my_unit(),'') <> ''
         and public.unit_of(u) = public.my_unit() then true
    else false
  end
$$;

-- Create a profile automatically when someone signs up
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'display_name', ''))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Only a Chapter Servant (or the SQL editor) may change roles, units or emails
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null
     and coalesce(public.my_role(), '') <> 'chapter'
     and (new.role is distinct from old.role
          or new.unit is distinct from old.unit
          or new.email is distinct from old.email
          or new.id is distinct from old.id) then
    raise exception 'Only a Chapter Servant can change roles and units';
  end if;
  return new;
end $$;

drop trigger if exists profiles_guard on public.profiles;
create trigger profiles_guard before update on public.profiles
  for each row execute function public.guard_profile();

alter table public.profiles enable row level security;

drop policy if exists "profiles: read own" on public.profiles;
create policy "profiles: read own" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "profiles: leaders read their people" on public.profiles;
create policy "profiles: leaders read their people" on public.profiles
  for select using (public.oversees(id));

drop policy if exists "profiles: update own name" on public.profiles;
create policy "profiles: update own name" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "profiles: chapter manages" on public.profiles;
create policy "profiles: chapter manages" on public.profiles
  for update using (public.my_role() = 'chapter');

-- ---------- 2. Private shepherd's folder (members, meetings, topics, settings) ----------
create table if not exists public.items (
  owner uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null,
  kind text not null,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (owner, id)
);

alter table public.items enable row level security;

-- Strictly private: nobody but the owner — not even Chapter Servants — can read these.
drop policy if exists "items: owner only" on public.items;
create policy "items: owner only" on public.items
  for all
  using (owner = auth.uid() and public.my_role() in ('household','unit','chapter'))
  with check (owner = auth.uid() and public.my_role() in ('household','unit','chapter'));

-- ---------- 3. Pastoral care referrals ("care flags") ----------
create table if not exists public.flags (
  id uuid primary key default gen_random_uuid(),
  sender uuid not null default auth.uid() references auth.users(id) on delete cascade,
  member_name text not null check (char_length(member_name) <= 200),
  household text not null default '' check (char_length(household) <= 200),
  category text not null check (char_length(category) <= 60),
  urgency text not null default 'week' check (urgency in ('week','urgent')),
  note text not null default '' check (char_length(note) <= 280),
  status text not null default 'open' check (status in ('open','ack','resolved')),
  response text not null default '' check (char_length(response) <= 500),
  created_on date not null default current_date,
  updated_at timestamptz not null default now()
);

create or replace function public.flag_on_insert() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.sender := auth.uid();
  new.status := 'open';
  new.response := '';
  new.created_on := current_date;
  return new;
end $$;

-- On update, only status and response may change
create or replace function public.flag_on_update() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.id := old.id; new.sender := old.sender; new.member_name := old.member_name;
  new.household := old.household; new.category := old.category; new.urgency := old.urgency;
  new.note := old.note; new.created_on := old.created_on; new.updated_at := now();
  return new;
end $$;

drop trigger if exists flags_insert on public.flags;
create trigger flags_insert before insert on public.flags
  for each row execute function public.flag_on_insert();
drop trigger if exists flags_update on public.flags;
create trigger flags_update before update on public.flags
  for each row execute function public.flag_on_update();

alter table public.flags enable row level security;

drop policy if exists "flags: sender or overseer reads" on public.flags;
create policy "flags: sender or overseer reads" on public.flags
  for select using (sender = auth.uid() or public.oversees(sender));

drop policy if exists "flags: approved leaders send" on public.flags;
create policy "flags: approved leaders send" on public.flags
  for insert with check (public.my_role() in ('household','unit','chapter'));

drop policy if exists "flags: overseer responds" on public.flags;
create policy "flags: overseer responds" on public.flags
  for update using (public.oversees(sender) and sender <> auth.uid());

-- ---------- 4. Counts-only household summaries for the unit/chapter view ----------
create table if not exists public.summaries (
  owner uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  updated_on date not null default current_date
);

create or replace function public.summary_owner() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then new.owner := auth.uid(); end if;
  new.updated_on := current_date;
  return new;
end $$;

drop trigger if exists summaries_owner on public.summaries;
create trigger summaries_owner before insert or update on public.summaries
  for each row execute function public.summary_owner();

alter table public.summaries enable row level security;

drop policy if exists "summaries: owner or overseer reads" on public.summaries;
create policy "summaries: owner or overseer reads" on public.summaries
  for select using (owner = auth.uid() or public.oversees(owner));

drop policy if exists "summaries: owner writes" on public.summaries;
create policy "summaries: owner writes" on public.summaries
  for all
  using (owner = auth.uid() and public.my_role() in ('household','unit','chapter'))
  with check (owner = auth.uid() and public.my_role() in ('household','unit','chapter'));

-- ---------- 5. Permissions for signed-in users ----------
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.items to authenticated;
grant select, insert, update on public.flags to authenticated;
grant select, insert, update, delete on public.summaries to authenticated;
revoke all on public.profiles, public.items, public.flags, public.summaries from anon;

-- =====================================================================
-- AFTER you create your own account in the app, make yourself the first
-- Chapter Servant by running this (replace the email):
--
--   update public.profiles set role = 'chapter', unit = ''
--   where email = 'you@example.com';
--
-- From then on, approve everyone else inside the app (Chapter tab > Leaders).
-- =====================================================================
