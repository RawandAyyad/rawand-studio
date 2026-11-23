-- ============================================================
-- Rawand Aldeeb Studio — database setup (run once in Supabase SQL Editor)
-- ============================================================

-- Who is the admin
create or replace function public.is_admin() returns boolean
language sql stable as $$
  select coalesce(lower(auth.jwt() ->> 'email') = 'rawandrr1989@gmail.com', false)
$$;

-- ---------- Requests (form submissions) ----------
create table if not exists public.requests (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  service text check (char_length(service) <= 80),
  budget text check (char_length(budget) <= 80),
  name text check (char_length(name) <= 120),
  contact text check (char_length(contact) <= 120),
  message text check (char_length(message) <= 3000),
  lang text check (lang in ('ar','en')),
  status text not null default 'new' check (status in ('new','in_progress','done')),
  note text check (char_length(note) <= 3000)
);
alter table public.requests enable row level security;
drop policy if exists "public can send requests" on public.requests;
create policy "public can send requests" on public.requests
  for insert to anon, authenticated with check (status = 'new' and note is null);
drop policy if exists "admin manages requests" on public.requests;
create policy "admin manages requests" on public.requests
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Analytics events ----------
create table if not exists public.events (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  type text not null check (char_length(type) <= 40),
  label text check (char_length(label) <= 160),
  path text check (char_length(path) <= 160),
  ref text check (char_length(ref) <= 160),
  device text check (device in ('mobile','tablet','desktop')),
  lang text check (lang in ('ar','en')),
  sid text check (char_length(sid) <= 40)
);
create index if not exists events_created_idx on public.events (created_at desc);
alter table public.events enable row level security;
drop policy if exists "public can log events" on public.events;
create policy "public can log events" on public.events
  for insert to anon, authenticated with check (true);
drop policy if exists "admin reads events" on public.events;
create policy "admin reads events" on public.events
  for select to authenticated using (public.is_admin());
drop policy if exists "admin deletes events" on public.events;
create policy "admin deletes events" on public.events
  for delete to authenticated using (public.is_admin());

-- ---------- Reviews ----------
create table if not exists public.reviews (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  name_ar text not null, name_en text,
  project_ar text, project_en text,
  text_ar text not null, text_en text,
  rating int not null default 5 check (rating between 1 and 5),
  avatar text not null default 'woman' check (avatar in ('woman','man')),
  sort int not null default 100,
  published boolean not null default true
);
alter table public.reviews enable row level security;
drop policy if exists "public reads published reviews" on public.reviews;
create policy "public reads published reviews" on public.reviews
  for select to anon, authenticated using (published or public.is_admin());
drop policy if exists "admin manages reviews" on public.reviews;
create policy "admin manages reviews" on public.reviews
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Projects ----------
create table if not exists public.projects (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  title_ar text not null, title_en text,
  category text not null check (category in ('social','logo','identity','motion')),
  desc_ar text, desc_en text,
  images jsonb not null default '[]'::jsonb,
  sort int not null default 100,
  published boolean not null default true
);
alter table public.projects enable row level security;
drop policy if exists "public reads published projects" on public.projects;
create policy "public reads published projects" on public.projects
  for select to anon, authenticated using (published or public.is_admin());
drop policy if exists "admin manages projects" on public.projects;
create policy "admin manages projects" on public.projects
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Image storage ----------
insert into storage.buckets (id, name, public)
values ('work', 'work', true)
on conflict (id) do update set public = true;
drop policy if exists "admin uploads work" on storage.objects;
create policy "admin uploads work" on storage.objects
  for insert to authenticated with check (bucket_id = 'work' and public.is_admin());
drop policy if exists "admin updates work" on storage.objects;
create policy "admin updates work" on storage.objects
  for update to authenticated using (bucket_id = 'work' and public.is_admin());
drop policy if exists "admin deletes work" on storage.objects;
create policy "admin deletes work" on storage.objects
  for delete to authenticated using (bucket_id = 'work' and public.is_admin());

-- ---------- Table privileges (new projects don't grant these automatically; RLS above still decides who sees what) ----------
grant usage on schema public to anon, authenticated;
grant insert on public.requests, public.events to anon, authenticated;
grant select on public.reviews, public.projects to anon, authenticated;
grant select, insert, update, delete on public.requests, public.events, public.reviews, public.projects to authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;
