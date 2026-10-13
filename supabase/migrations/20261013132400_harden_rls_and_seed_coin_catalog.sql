-- ListingoAI security and RLS hardening
drop policy if exists "Enable read access for all users" on public.users;
create policy "Users can read their safe profile" on public.users for select to authenticated using ((select auth.uid()) = id);
revoke all on public.users from anon, authenticated;
grant select (id, name, email, plan, billing_status, daily_usage_count, daily_usage_date, monthly_usage_count, created_at) on public.users to authenticated;

drop policy if exists "Users can create their own conversations" on public.agent_conversations;
drop policy if exists "Users can delete their own conversations" on public.agent_conversations;
drop policy if exists "Users can read their own conversations" on public.agent_conversations;
drop policy if exists "Users can update their own conversations" on public.agent_conversations;
create policy "Users can create their own conversations" on public.agent_conversations for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can read their own conversations" on public.agent_conversations for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can update their own conversations" on public.agent_conversations for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete their own conversations" on public.agent_conversations for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their own messages" on public.agent_messages;
drop policy if exists "Users can delete their own messages" on public.agent_messages;
drop policy if exists "Users can read their own messages" on public.agent_messages;
create policy "Users can create their own messages" on public.agent_messages for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can read their own messages" on public.agent_messages for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can delete their own messages" on public.agent_messages for delete to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "Users can insert their own analytics" on public.analytics_events;
drop policy if exists "Users can read their own analytics" on public.analytics_events;
create policy "Users can insert their own analytics" on public.analytics_events for insert to anon, authenticated with check (((select auth.uid()) = user_id) or user_id is null);
create policy "Users can read their own analytics" on public.analytics_events for select to authenticated using ((select auth.uid()) = user_id);

insert into public.coins (id, symbol, name, slug, rank, is_active) values
('bitcoin','BTC','Bitcoin','bitcoin',1,true),
('ethereum','ETH','Ethereum','ethereum',2,true),
('tether','USDT','Tether','tether',3,true),
('binancecoin','BNB','BNB','bnb',4,true),
('solana','SOL','Solana','solana',5,true),
('usd-coin','USDC','USDC','usd-coin',6,true),
('xrp','XRP','XRP','xrp',7,true),
('dogecoin','DOGE','Dogecoin','dogecoin',8,true),
('cardano','ADA','Cardano','cardano',9,true),
('avalanche-2','AVAX','Avalanche','avalanche-2',10,true),
('chainlink','LINK','Chainlink','chainlink',11,true),
('polkadot','DOT','Polkadot','polkadot',12,true)
on conflict (id) do update set symbol=excluded.symbol,name=excluded.name,slug=excluded.slug,rank=excluded.rank,is_active=excluded.is_active,updated_at=now();
