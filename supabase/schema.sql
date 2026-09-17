-- ============================================================================
-- Gerador de Orçamentos · miligrama design
-- Schema completo. Cole e rode no SQL Editor do Supabase Studio
-- (Vercel > Storage > [seu banco] > Open in Supabase).
-- É idempotente: pode rodar de novo sem quebrar nada.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Tabelas
-- ---------------------------------------------------------------------------

create table if not exists public.propostas_geradas (
  id              bigint generated always as identity primary key,
  numero_proposta text        not null,
  ano             int         not null,
  cliente         text        not null default 'sem nome',
  apresentacao    text,
  servicos        jsonb       not null default '[]'::jsonb,
  cronograma      jsonb       not null default '[]'::jsonb,
  validade_dias   int         not null default 30,
  valor_total     numeric(12,2) not null default 0,
  criado_em       timestamptz not null default now()
);

-- O histórico é lido por criado_em desc.
create index if not exists propostas_geradas_criado_em_idx
  on public.propostas_geradas (criado_em desc);

-- Contador de numeração das propostas. Uma única linha, id = 1.
create table if not exists public.proposta_contador (
  id             int primary key,
  proximo_numero int not null
);

-- Semente: a primeira proposta gerada sai com o número 12,
-- que é o mesmo fallback que o app usa quando não consegue ler o contador.
insert into public.proposta_contador (id, proximo_numero)
values (1, 12)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 2. RPC: pega o número atual e já incrementa o contador, de forma atômica
-- ---------------------------------------------------------------------------
-- security definer de propósito: roda com os privilégios do dono da função,
-- então o anon consegue incrementar o contador SEM ter permissão de UPDATE
-- direto na tabela. É isso que impede alguém de reescrever a numeração à mão.

create or replace function public.obter_proximo_numero_proposta()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  numero int;
begin
  update public.proposta_contador
     set proximo_numero = proximo_numero + 1
   where id = 1
  returning proximo_numero - 1 into numero;

  -- Se a linha do contador tiver sumido, recria começando do 12.
  if numero is null then
    insert into public.proposta_contador (id, proximo_numero)
    values (1, 13)
    on conflict (id) do update set proximo_numero = excluded.proximo_numero
    returning proximo_numero - 1 into numero;
  end if;

  return numero;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------------------
-- A publishable key fica visível no index.html (app estático, sem build),
-- então é a RLS — e só ela — que define o que o público pode fazer.

alter table public.propostas_geradas  enable row level security;
alter table public.proposta_contador  enable row level security;

drop policy if exists "anon le propostas"      on public.propostas_geradas;
drop policy if exists "anon insere propostas"  on public.propostas_geradas;
drop policy if exists "anon edita propostas"   on public.propostas_geradas;
drop policy if exists "anon le contador"       on public.proposta_contador;

create policy "anon le propostas"
  on public.propostas_geradas for select
  to anon, authenticated
  using (true);

create policy "anon insere propostas"
  on public.propostas_geradas for insert
  to anon, authenticated
  with check (true);

-- Necessario para reabrir uma proposta do historico e regravar a mesma linha,
-- mantendo numero e data. ATENCAO: como a publishable key e publica, isso
-- significa que qualquer pessoa com a key pode reescrever qualquer proposta.
-- A protecao de verdade aqui seria autenticacao (Supabase Auth); enquanto nao
-- houver, o update fica aberto igual ao select e ao insert.
create policy "anon edita propostas"
  on public.propostas_geradas for update
  to anon, authenticated
  using (true)
  with check (true);

create policy "anon le contador"
  on public.proposta_contador for select
  to anon, authenticated
  using (true);

-- Sem policy de delete: ninguém apaga proposta pela API pública.

-- ---------------------------------------------------------------------------
-- 4. Grants
-- ---------------------------------------------------------------------------
-- O Postgres checa os grants ANTES da RLS. Sem isso, a policy nem é avaliada.

grant usage on schema public to anon, authenticated;

grant select, insert, update on public.propostas_geradas to anon, authenticated;
grant select          on public.proposta_contador to anon, authenticated;

grant execute on function public.obter_proximo_numero_proposta() to anon, authenticated;

-- Garante que o anon NÃO mexe no contador por fora da RPC.
revoke insert, update, delete on public.proposta_contador from anon, authenticated;
revoke delete                 on public.propostas_geradas  from anon, authenticated;
