create table if not exists public.exchange_rate_snapshots (
  id uuid primary key default gen_random_uuid(),
  base_currency text not null,
  provider text not null default 'exchangerate-api',
  effective_date date not null,
  provider_last_update_at timestamptz not null,
  provider_last_update_unix bigint,
  provider_next_update_at timestamptz not null,
  provider_next_update_unix bigint,
  fetched_at timestamptz not null default now(),
  next_update_at timestamptz not null,
  rates jsonb not null,
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exchange_rate_snapshots_base_upper check (base_currency = upper(base_currency)),
  constraint exchange_rate_snapshots_unique_provider_update unique (base_currency, provider_last_update_at)
);

alter table public.exchange_rate_snapshots
add column if not exists provider_last_update_at timestamptz,
add column if not exists provider_last_update_unix bigint,
add column if not exists provider_next_update_at timestamptz,
add column if not exists provider_next_update_unix bigint;

update public.exchange_rate_snapshots
set
  provider_last_update_at = coalesce(provider_last_update_at, effective_date::timestamptz),
  provider_next_update_at = coalesce(provider_next_update_at, next_update_at)
where provider_last_update_at is null
   or provider_next_update_at is null;

alter table public.exchange_rate_snapshots
alter column provider_last_update_at set not null,
alter column provider_next_update_at set not null;

alter table public.exchange_rate_snapshots
drop constraint if exists exchange_rate_snapshots_unique_day;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'exchange_rate_snapshots_unique_provider_update'
      and conrelid = 'public.exchange_rate_snapshots'::regclass
  ) then
    alter table public.exchange_rate_snapshots
    add constraint exchange_rate_snapshots_unique_provider_update
    unique (base_currency, provider_last_update_at);
  end if;
end;
$$;

create index if not exists exchange_rate_snapshots_latest_idx
  on public.exchange_rate_snapshots (base_currency, provider_last_update_at desc, fetched_at desc);

create index if not exists exchange_rate_snapshots_next_update_idx
  on public.exchange_rate_snapshots (base_currency, next_update_at desc);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_exchange_rate_snapshots_updated_at on public.exchange_rate_snapshots;

create trigger set_exchange_rate_snapshots_updated_at
before update on public.exchange_rate_snapshots
for each row execute function public.set_updated_at();

alter table public.exchange_rate_snapshots enable row level security;

drop policy if exists "Public can read exchange rate snapshots" on public.exchange_rate_snapshots;
create policy "Public can read exchange rate snapshots"
on public.exchange_rate_snapshots
for select
to anon, authenticated
using (true);
