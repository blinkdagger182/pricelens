alter table public.exchange_rate_snapshots
add column if not exists provider_last_update_at timestamptz;

alter table public.exchange_rate_snapshots
add column if not exists provider_last_update_unix bigint;

alter table public.exchange_rate_snapshots
add column if not exists provider_next_update_at timestamptz;

alter table public.exchange_rate_snapshots
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

drop index if exists exchange_rate_snapshots_latest_idx;
create index exchange_rate_snapshots_latest_idx
  on public.exchange_rate_snapshots (base_currency, provider_last_update_at desc, fetched_at desc);

create index if not exists exchange_rate_snapshots_provider_next_update_idx
  on public.exchange_rate_snapshots (base_currency, provider_next_update_at desc);
