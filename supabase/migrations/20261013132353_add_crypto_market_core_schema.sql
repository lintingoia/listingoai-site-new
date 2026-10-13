-- ListingoAI crypto market core schema
create table if not exists public.coins (
  id text primary key,
  symbol text not null,
  name text not null,
  slug text unique,
  image_url text,
  rank integer,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists coins_rank_idx on public.coins(rank) where is_active = true;
create index if not exists coins_symbol_idx on public.coins(lower(symbol));

create table if not exists public.market_snapshots (
  id uuid primary key default gen_random_uuid(),
  coin_id text not null references public.coins(id) on delete cascade,
  captured_at timestamptz not null default now(),
  price_usd numeric(30,12),
  market_cap_usd numeric(38,2),
  volume_24h_usd numeric(38,2),
  change_24h numeric(12,6),
  high_24h_usd numeric(30,12),
  low_24h_usd numeric(30,12),
  circulating_supply numeric(40,12),
  total_supply numeric(40,12),
  max_supply numeric(40,12),
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists market_snapshots_coin_time_idx on public.market_snapshots(coin_id, captured_at desc);
create index if not exists market_snapshots_time_idx on public.market_snapshots(captured_at desc);

create table if not exists public.price_history (
  coin_id text not null references public.coins(id) on delete cascade,
  interval text not null,
  bucket_start timestamptz not null,
  open numeric(30,12) not null,
  high numeric(30,12) not null,
  low numeric(30,12) not null,
  close numeric(30,12) not null,
  volume_usd numeric(38,2),
  market_cap_usd numeric(38,2),
  primary key (coin_id, interval, bucket_start),
  constraint price_history_interval_check check (interval in ('1m','5m','15m','1h','4h','1d','1w'))
);
create index if not exists price_history_coin_interval_time_idx on public.price_history(coin_id, interval, bucket_start desc);

create table if not exists public.watchlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null default 'Main Watchlist',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, name)
);
create index if not exists watchlists_user_idx on public.watchlists(user_id);

create table if not exists public.watchlist_items (
  id uuid primary key default gen_random_uuid(),
  watchlist_id uuid not null references public.watchlists(id) on delete cascade,
  coin_id text not null references public.coins(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(watchlist_id, coin_id)
);
create index if not exists watchlist_items_watchlist_idx on public.watchlist_items(watchlist_id);
create index if not exists watchlist_items_coin_idx on public.watchlist_items(coin_id);

create table if not exists public.portfolio_assets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  coin_id text not null references public.coins(id) on delete restrict,
  quantity numeric(40,18) not null default 0 check (quantity >= 0),
  avg_cost_usd numeric(30,12) not null default 0 check (avg_cost_usd >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, coin_id)
);
create index if not exists portfolio_assets_user_idx on public.portfolio_assets(user_id);
create index if not exists portfolio_assets_coin_idx on public.portfolio_assets(coin_id);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  coin_id text references public.coins(id) on delete cascade,
  alert_type text not null,
  operator text not null,
  threshold numeric(30,12),
  timeframe text,
  message text,
  metadata jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  last_triggered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint alerts_type_check check (alert_type in ('price','change','volume','ai','market')),
  constraint alerts_operator_check check (operator in ('gt','gte','lt','lte','eq'))
);
create index if not exists alerts_user_active_idx on public.alerts(user_id, is_active);
create index if not exists alerts_coin_active_idx on public.alerts(coin_id, is_active);

create table if not exists public.ai_analyses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  coin_id text references public.coins(id) on delete set null,
  horizon text not null,
  question text not null,
  answer text not null,
  direction text,
  confidence numeric(5,2),
  signals jsonb not null default '{}'::jsonb,
  model text,
  data_as_of timestamptz,
  created_at timestamptz not null default now(),
  constraint ai_analyses_horizon_check check (horizon in ('short','medium','long','multi','custom')),
  constraint ai_analyses_direction_check check (direction is null or direction in ('bullish','neutral','bearish','mixed'))
);
create index if not exists ai_analyses_coin_time_idx on public.ai_analyses(coin_id, created_at desc);
create index if not exists ai_analyses_user_time_idx on public.ai_analyses(user_id, created_at desc);
create index if not exists ai_analyses_public_idx on public.ai_analyses(created_at desc) where user_id is null;

alter table public.coins enable row level security;
alter table public.market_snapshots enable row level security;
alter table public.price_history enable row level security;
alter table public.watchlists enable row level security;
alter table public.watchlist_items enable row level security;
alter table public.portfolio_assets enable row level security;
alter table public.alerts enable row level security;
alter table public.ai_analyses enable row level security;

drop policy if exists "Public can read active coins" on public.coins;
create policy "Public can read active coins" on public.coins for select to anon, authenticated using (is_active = true);

drop policy if exists "Public can read market snapshots" on public.market_snapshots;
create policy "Public can read market snapshots" on public.market_snapshots for select to anon, authenticated using (true);

drop policy if exists "Public can read price history" on public.price_history;
create policy "Public can read price history" on public.price_history for select to anon, authenticated using (true);

drop policy if exists "Users can read their watchlists" on public.watchlists;
create policy "Users can read their watchlists" on public.watchlists for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their watchlists" on public.watchlists;
create policy "Users can create their watchlists" on public.watchlists for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their watchlists" on public.watchlists;
create policy "Users can update their watchlists" on public.watchlists for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their watchlists" on public.watchlists;
create policy "Users can delete their watchlists" on public.watchlists for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can manage watchlist items" on public.watchlist_items;
create policy "Users can manage watchlist items" on public.watchlist_items for all to authenticated
using (exists (select 1 from public.watchlists w where w.id = watchlist_id and w.user_id = (select auth.uid())))
with check (exists (select 1 from public.watchlists w where w.id = watchlist_id and w.user_id = (select auth.uid())));

drop policy if exists "Users can read their portfolio" on public.portfolio_assets;
create policy "Users can read their portfolio" on public.portfolio_assets for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their portfolio" on public.portfolio_assets;
create policy "Users can create their portfolio" on public.portfolio_assets for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their portfolio" on public.portfolio_assets;
create policy "Users can update their portfolio" on public.portfolio_assets for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their portfolio" on public.portfolio_assets;
create policy "Users can delete their portfolio" on public.portfolio_assets for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can read their alerts" on public.alerts;
create policy "Users can read their alerts" on public.alerts for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "Users can create their alerts" on public.alerts;
create policy "Users can create their alerts" on public.alerts for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "Users can update their alerts" on public.alerts;
create policy "Users can update their alerts" on public.alerts for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
drop policy if exists "Users can delete their alerts" on public.alerts;
create policy "Users can delete their alerts" on public.alerts for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can read public or own AI analyses" on public.ai_analyses;
create policy "Users can read public or own AI analyses" on public.ai_analyses for select to anon, authenticated
using (user_id is null or (select auth.uid()) = user_id);

create index if not exists agent_messages_user_id_idx on public.agent_messages(user_id);
create index if not exists analytics_events_user_id_idx on public.analytics_events(user_id);
create index if not exists password_resets_user_id_idx on public.password_resets(user_id);
