-- ============================================================================
-- Migração 002 — permitir reabrir e regravar uma proposta do histórico
-- Rodar no SQL Editor do Supabase Studio. Idempotente.
--
-- ATENÇÃO: a publishable key fica visível no index.html, então liberar UPDATE
-- significa que qualquer pessoa com a key pode reescrever qualquer proposta.
-- Isso já valia para leitura e inserção; o update amplia para adulteração.
-- A solução de verdade é autenticação (Supabase Auth) — enquanto não houver,
-- o acesso segue aberto.
-- ============================================================================

drop policy if exists "anon edita propostas" on public.propostas_geradas;

create policy "anon edita propostas"
  on public.propostas_geradas for update
  to anon, authenticated
  using (true)
  with check (true);

grant update on public.propostas_geradas to anon, authenticated;

-- delete continua bloqueado
revoke delete on public.propostas_geradas from anon, authenticated;
