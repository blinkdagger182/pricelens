create table if not exists public.app_version_policies (
  platform text primary key,
  minimum_supported_version text not null,
  latest_version text not null,
  is_enabled boolean not null default true,
  update_title text,
  update_message text,
  release_notes text[] not null default '{}',
  app_store_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_version_policies_platform_check check (platform in ('ios'))
);

drop trigger if exists set_app_version_policies_updated_at on public.app_version_policies;

create trigger set_app_version_policies_updated_at
before update on public.app_version_policies
for each row execute function public.set_updated_at();

alter table public.app_version_policies enable row level security;

drop policy if exists "Public can read app version policies" on public.app_version_policies;
create policy "Public can read app version policies"
on public.app_version_policies
for select
to anon, authenticated
using (is_enabled = true);

insert into public.app_version_policies (
  platform,
  minimum_supported_version,
  latest_version,
  update_title,
  update_message,
  release_notes,
  app_store_url
) values (
  'ios',
  '1.0.0',
  '1.0.0',
  'A new Pricetag AI update is ready',
  'Update to the latest version for faster scanning, fresher rates, and a smoother travel camera experience.',
  array[
    'Improved live price detection',
    'Cleaner snap overlays',
    'Updated exchange-rate reliability'
  ],
  null
)
on conflict (platform) do nothing;
