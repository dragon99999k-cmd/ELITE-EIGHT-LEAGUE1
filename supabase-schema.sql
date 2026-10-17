-- ELITE EIGHT LEAGUE — Supabase schema
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- Then create your admin account in Authentication > Users and add its UUID using the instructions in README.md.

create extension if not exists pgcrypto;

create table if not exists public.teams (
  id text primary key,
  name text not null unique,
  short text not null,
  badge_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.matches (
  id text primary key,
  round_number integer not null check (round_number between 1 and 7),
  home_team_id text not null references public.teams(id) on delete restrict,
  away_team_id text not null references public.teams(id) on delete restrict,
  home_score integer check (home_score is null or home_score between 0 and 99),
  away_score integer check (away_score is null or away_score between 0 and 99),
  status text not null default 'scheduled' check (status in ('scheduled','live','finished','postponed')),
  kickoff_at timestamptz,
  venue text,
  featured boolean not null default false,
  created_at timestamptz not null default now(),
  check (home_team_id <> away_team_id),
  check ((home_score is null and away_score is null) or (home_score is not null and away_score is not null))
);

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  team_id text not null references public.teams(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id text not null references public.matches(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete restrict,
  event_type text not null check (event_type in ('goal')),
  minute integer check (minute is null or minute between 1 and 130),
  created_at timestamptz not null default now()
);

create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 100),
  body text not null check (char_length(body) between 1 and 1500),
  created_at timestamptz not null default now()
);

create table if not exists public.season_archives (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  standings jsonb not null default '[]'::jsonb,
  results jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Only users whose auth UUID is listed here can change league data.
create table if not exists public.league_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_league_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.league_admins where user_id = auth.uid());
$$;
revoke all on function public.is_league_admin() from public;
grant execute on function public.is_league_admin() to anon, authenticated;

alter table public.teams enable row level security;
alter table public.matches enable row level security;
alter table public.players enable row level security;
alter table public.match_events enable row level security;
alter table public.announcements enable row level security;
alter table public.season_archives enable row level security;
alter table public.league_admins enable row level security;

-- Public read; admin-only writes.
create policy "Public can read teams" on public.teams for select to anon, authenticated using (true);
create policy "Admins manage teams" on public.teams for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Public can read matches" on public.matches for select to anon, authenticated using (true);
create policy "Admins manage matches" on public.matches for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Public can read players" on public.players for select to anon, authenticated using (true);
create policy "Admins manage players" on public.players for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Public can read match events" on public.match_events for select to anon, authenticated using (true);
create policy "Admins manage match events" on public.match_events for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Public can read announcements" on public.announcements for select to anon, authenticated using (true);
create policy "Admins manage announcements" on public.announcements for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Public can read season archives" on public.season_archives for select to anon, authenticated using (true);
create policy "Admins manage season archives" on public.season_archives for all to authenticated using (public.is_league_admin()) with check (public.is_league_admin());

create policy "Admins can read admin list" on public.league_admins for select to authenticated using (user_id = auth.uid() or public.is_league_admin());

insert into public.teams (id,name,short) values
  ('aflatoon-fc','AFLATOON FC','AF'),
  ('3mory-fc','3MORY FC','3M'),
  ('bahaa-fc','BAHAA FC','BH'),
  ('amir-fc','AMIR FC','AM'),
  ('adam-fc','ADAM FC','AD'),
  ('3mory-osama-fc','3MORY OSAMA FC','3O'),
  ('trader-fc','TRADER FC','TR'),
  ('altaier-fc','ALTAIER FC','AL')
on conflict (id) do update set name=excluded.name, short=excluded.short;

-- 7 round-robin matchdays (4 matches each, 28 matches total).
insert into public.matches (id,round_number,home_team_id,away_team_id) values
  ('r1m1',1,'aflatoon-fc','altaier-fc'),
  ('r1m2',1,'trader-fc','3mory-fc'),
  ('r1m3',1,'bahaa-fc','3mory-osama-fc'),
  ('r1m4',1,'adam-fc','amir-fc'),
  ('r2m1',2,'trader-fc','aflatoon-fc'),
  ('r2m2',2,'altaier-fc','3mory-osama-fc'),
  ('r2m3',2,'adam-fc','3mory-fc'),
  ('r2m4',2,'bahaa-fc','amir-fc'),
  ('r3m1',3,'aflatoon-fc','3mory-osama-fc'),
  ('r3m2',3,'adam-fc','trader-fc'),
  ('r3m3',3,'altaier-fc','amir-fc'),
  ('r3m4',3,'bahaa-fc','3mory-fc'),
  ('r4m1',4,'adam-fc','aflatoon-fc'),
  ('r4m2',4,'3mory-osama-fc','amir-fc'),
  ('r4m3',4,'bahaa-fc','trader-fc'),
  ('r4m4',4,'altaier-fc','3mory-fc'),
  ('r5m1',5,'aflatoon-fc','amir-fc'),
  ('r5m2',5,'bahaa-fc','adam-fc'),
  ('r5m3',5,'3mory-osama-fc','3mory-fc'),
  ('r5m4',5,'altaier-fc','trader-fc'),
  ('r6m1',6,'bahaa-fc','aflatoon-fc'),
  ('r6m2',6,'amir-fc','3mory-fc'),
  ('r6m3',6,'altaier-fc','adam-fc'),
  ('r6m4',6,'3mory-osama-fc','trader-fc'),
  ('r7m1',7,'aflatoon-fc','3mory-fc'),
  ('r7m2',7,'altaier-fc','bahaa-fc'),
  ('r7m3',7,'amir-fc','trader-fc'),
  ('r7m4',7,'3mory-osama-fc','adam-fc')
on conflict (id) do nothing;

-- Public read access to uploaded badge images; only authenticated league admins can write.
insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('team-badges','team-badges',true,3145728,array['image/png','image/jpeg','image/webp','image/svg+xml'])
on conflict (id) do update set public=true, file_size_limit=3145728, allowed_mime_types=array['image/png','image/jpeg','image/webp','image/svg+xml'];

create policy "Public can view team badges" on storage.objects for select using (bucket_id = 'team-badges');
create policy "League admins upload team badges" on storage.objects for insert to authenticated with check (bucket_id = 'team-badges' and public.is_league_admin());
create policy "League admins update team badges" on storage.objects for update to authenticated using (bucket_id = 'team-badges' and public.is_league_admin()) with check (bucket_id = 'team-badges' and public.is_league_admin());
create policy "League admins delete team badges" on storage.objects for delete to authenticated using (bucket_id = 'team-badges' and public.is_league_admin());

-- Explicit table privileges (RLS above still decides which rows can be changed).
grant select on public.teams, public.matches, public.players, public.match_events, public.announcements, public.season_archives to anon, authenticated;
grant insert, update, delete on public.teams, public.matches, public.players, public.match_events, public.announcements, public.season_archives to authenticated;
grant select on public.league_admins to authenticated;
