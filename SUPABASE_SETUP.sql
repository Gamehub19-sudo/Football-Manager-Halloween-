-- Execute no Supabase: SQL Editor > New query > Run.
-- Esta tabela armazena o progresso completo separado para cada conta autenticada.
create table if not exists public.player_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  save_data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.player_saves enable row level security;

drop policy if exists "Jogador lê o próprio salvamento" on public.player_saves;
create policy "Jogador lê o próprio salvamento"
  on public.player_saves for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Jogador cria o próprio salvamento" on public.player_saves;
create policy "Jogador cria o próprio salvamento"
  on public.player_saves for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Jogador atualiza o próprio salvamento" on public.player_saves;
create policy "Jogador atualiza o próprio salvamento"
  on public.player_saves for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);


-- RANKING GLOBAL: tabelas usadas pelo jogo para pontuações públicas.
-- Os nomes dos clubes são a chave única usada pelo upsert (on_conflict=player_name).
create table if not exists public.global_ranking (
  player_name text primary key check (char_length(player_name) between 1 and 28),
  fame numeric not null default 0 check (fame >= 0),
  money numeric not null default 0 check (money >= 0),
  team_strength numeric not null default 0 check (team_strength >= 0),
  trophies numeric not null default 0 check (trophies >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.global_gem_ranking (
  player_name text primary key check (char_length(player_name) between 1 and 28),
  gems numeric not null default 0 check (gems >= 0),
  updated_at timestamptz not null default now()
);

create index if not exists global_ranking_money_idx on public.global_ranking (money desc);
create index if not exists global_ranking_fame_idx on public.global_ranking (fame desc);
create index if not exists global_ranking_trophies_idx on public.global_ranking (trophies desc);
create index if not exists global_gem_ranking_gems_idx on public.global_gem_ranking (gems desc);

alter table public.global_ranking enable row level security;
alter table public.global_gem_ranking enable row level security;

grant select, insert, update, delete on public.global_ranking to anon, authenticated;
grant select, insert, update, delete on public.global_gem_ranking to anon, authenticated;

drop policy if exists "Ranking global: leitura pública" on public.global_ranking;
create policy "Ranking global: leitura pública" on public.global_ranking
  for select to anon, authenticated using (true);
drop policy if exists "Ranking global: inserção pública" on public.global_ranking;
create policy "Ranking global: inserção pública" on public.global_ranking
  for insert to anon, authenticated with check (true);
drop policy if exists "Ranking global: atualização pública" on public.global_ranking;
create policy "Ranking global: atualização pública" on public.global_ranking
  for update to anon, authenticated using (true) with check (true);
drop policy if exists "Ranking global: exclusão pública" on public.global_ranking;
create policy "Ranking global: exclusão pública" on public.global_ranking
  for delete to anon, authenticated using (true);

drop policy if exists "Ranking de gemas: leitura pública" on public.global_gem_ranking;
create policy "Ranking de gemas: leitura pública" on public.global_gem_ranking
  for select to anon, authenticated using (true);
drop policy if exists "Ranking de gemas: inserção pública" on public.global_gem_ranking;
create policy "Ranking de gemas: inserção pública" on public.global_gem_ranking
  for insert to anon, authenticated with check (true);
drop policy if exists "Ranking de gemas: atualização pública" on public.global_gem_ranking;
create policy "Ranking de gemas: atualização pública" on public.global_gem_ranking
  for update to anon, authenticated using (true) with check (true);
drop policy if exists "Ranking de gemas: exclusão pública" on public.global_gem_ranking;
create policy "Ranking de gemas: exclusão pública" on public.global_gem_ranking
  for delete to anon, authenticated using (true);

-- A interface existente chama esta função ao solicitar a limpeza do ranking.
create or replace function public.reset_global_ranking(reset_code text)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if reset_code is distinct from 'Reiniciar Ranking' then
    raise exception 'Código de reinicialização inválido';
  end if;
  delete from public.global_ranking;
  delete from public.global_gem_ranking;
end;
$$;
revoke all on function public.reset_global_ranking(text) from public;
grant execute on function public.reset_global_ranking(text) to anon, authenticated;

-- IMPORTANTE: como o jogo usa uma chave pública no navegador, as políticas acima
-- permitem escrita e exclusão públicas. Isso é adequado apenas para um ranking
-- demonstrativo; não use esse modelo para dados competitivos que precisem ser invioláveis.
