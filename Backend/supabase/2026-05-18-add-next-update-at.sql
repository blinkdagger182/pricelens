alter table public.exchange_rate_snapshots
add column if not exists next_update_at timestamptz;

update public.exchange_rate_snapshots
set next_update_at = coalesce(next_update_at, fetched_at + interval '24 hours')
where next_update_at is null;

alter table public.exchange_rate_snapshots
alter column next_update_at set not null;

create index if not exists exchange_rate_snapshots_next_update_idx
  on public.exchange_rate_snapshots (base_currency, next_update_at desc);

