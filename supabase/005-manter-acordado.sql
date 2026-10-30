-- ============================================================================
-- Migração 005 — registro de "pings" para manter o projeto acordado.
-- Cada chamada GRAVA uma linha (escrita conta como atividade de banco com
-- mais certeza do que leitura) e deixa um histórico para conferir se os
-- agendamentos estão rodando de fato. Idempotente.
-- ============================================================================

create table if not exists public.manter_acordado (
  id     bigint generated always as identity primary key,
  em     timestamptz not null default now(),
  origem text
);

alter table public.manter_acordado enable row level security;

-- grava o ping e mantém só os 200 mais recentes
create or replace function public.registrar_ping(p_origem text default null)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.manter_acordado (origem) values (p_origem);
  delete from public.manter_acordado
   where id < (select id from public.manter_acordado order by id desc offset 199 limit 1);
  return now();
end;
$$;

-- leitura do histórico liberada (são só horários); escrita só pela função
drop policy if exists "anon le pings" on public.manter_acordado;
create policy "anon le pings" on public.manter_acordado for select to anon, authenticated using (true);
grant select on public.manter_acordado to anon, authenticated;
revoke insert, update, delete on public.manter_acordado from anon, authenticated;
grant execute on function public.registrar_ping(text) to anon, authenticated;
