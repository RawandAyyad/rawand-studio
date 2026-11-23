-- ============================================================
-- Analytics upgrade: visitor country (and city when available)
-- Run once in Supabase → SQL Editor. Safe to run again.
-- No IP address is stored: the country comes from the request headers
-- Supabase receives (Cloudflare adds them), and is filled in by the database
-- itself, so a visitor can't fake it.
-- ============================================================

alter table public.events add column if not exists country text;
alter table public.events add column if not exists city text;
alter table public.events drop constraint if exists events_country_len;
alter table public.events add constraint events_country_len check (country is null or char_length(country) = 2);
alter table public.events drop constraint if exists events_city_len;
alter table public.events add constraint events_city_len check (city is null or char_length(city) <= 80);

create or replace function public.events_geo() returns trigger
language plpgsql as $$
declare h json;
begin
  begin
    h := current_setting('request.headers', true)::json;
  exception when others then
    h := null;
  end;
  new.country := null;
  new.city := null;
  if h is not null then
    new.country := nullif(upper(left(coalesce(h ->> 'cf-ipcountry', ''), 2)), '');
    if new.country is not null and (new.country !~ '^[A-Z]{2}$' or new.country in ('XX', 'T1')) then
      new.country := null;
    end if;
    new.city := nullif(left(coalesce(h ->> 'cf-ipcity', ''), 80), '');
  end if;
  return new;
end
$$;

drop trigger if exists events_geo on public.events;
create trigger events_geo before insert on public.events
  for each row execute function public.events_geo();

create index if not exists events_country_idx on public.events (country);
