-- Just Mine: online setup (accounts + leaderboard)
-- Paste ALL of this into Supabase -> SQL Editor -> New query -> Run. Running it twice is safe.

-- One row per player. The login itself (password etc.) lives in Supabase's own auth.users table,
-- where the password is only stored hashed. This table just holds the public leaderboard info.
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[A-Za-z0-9_]{3,16}$'),
  best double precision not null default 0,   -- best Creditz ever (numbers go past 1e24, so not bigint)
  rebirths integer not null default 0,
  pass_lvl integer not null default 0,
  updated_at timestamptz not null default now()
);

-- Row Level Security: the anon key in the game is public, so these rules are what protect the data.
alter table public.profiles enable row level security;
drop policy if exists "leaderboard is public" on public.profiles;
create policy "leaderboard is public" on public.profiles for select using (true);
drop policy if exists "players update their own row" on public.profiles;
create policy "players update their own row" on public.profiles for update
  using (auth.uid() = id) with check (auth.uid() = id);
-- (no insert/delete policy: rows are created by the trigger below, and nobody can delete others)

-- When someone signs up, make their leaderboard row from the username the game sends along.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username) values (new.id, new.raw_user_meta_data->>'username');
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Scores can only go UP, values are capped, and the username can't be changed from the game.
create or replace function public.keep_best() returns trigger language plpgsql as $$
begin
  new.id := old.id;
  new.username := old.username;
  new.best := greatest(old.best, least(coalesce(new.best, 0), 1e300));
  new.rebirths := greatest(old.rebirths, least(coalesce(new.rebirths, 0), 100000));
  new.pass_lvl := greatest(old.pass_lvl, least(coalesce(new.pass_lvl, 0), 50));
  new.updated_at := now();
  return new;
end; $$;
drop trigger if exists keep_best on public.profiles;
create trigger keep_best before update on public.profiles
  for each row execute function public.keep_best();

-- Cloud saves: each player's whole save, so progress belongs to the account (and works on every device).
-- Only the owner can read or write their own save.
create table if not exists public.saves (
  id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null check (octet_length(data::text) < 1000000),
  updated_at timestamptz not null default now()
);
alter table public.saves enable row level security;
drop policy if exists "read own save" on public.saves;
create policy "read own save" on public.saves for select using (auth.uid() = id);
drop policy if exists "create own save" on public.saves;
create policy "create own save" on public.saves for insert with check (auth.uid() = id);
drop policy if exists "update own save" on public.saves;
create policy "update own save" on public.saves for update using (auth.uid() = id) with check (auth.uid() = id);

create index if not exists profiles_best_idx on public.profiles (best desc);
create index if not exists profiles_rebirths_idx on public.profiles (rebirths desc);
create index if not exists profiles_pass_idx on public.profiles (pass_lvl desc);
