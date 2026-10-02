-- Migração 004 — fundo do documento (escuro | claro).
-- Propostas já gravadas assumem 'escuro', que é como elas foram feitas.
alter table public.propostas_geradas
  add column if not exists tema text not null default 'escuro';
