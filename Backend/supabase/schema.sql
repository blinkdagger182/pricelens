create table if not exists public.exchange_rate_snapshots (
  id uuid primary key default gen_random_uuid(),
  base_currency text not null,
  provider text not null default 'exchangerate-api',
  effective_date date not null,
  fetched_at timestamptz not null default now(),
  next_update_at timestamptz not null,
  rates jsonb not null,
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exchange_rate_snapshots_base_upper check (base_currency = upper(base_currency)),
  constraint exchange_rate_snapshots_unique_day unique (base_currency, effective_date)
);

create index if not exists exchange_rate_snapshots_latest_idx
  on public.exchange_rate_snapshots (base_currency, effective_date desc, fetched_at desc);

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
