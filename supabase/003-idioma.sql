-- Migração 003 — idioma do documento (pt | en)
-- Propostas já gravadas assumem 'pt', que é o que elas de fato são.
alter table public.propostas_geradas
  add column if not exists idioma text not null default 'pt';
