# Gerador de Orçamentos · miligrama design

App de propostas comerciais. HTML único, React 18 via CDN, JSX compilado no
navegador pelo Babel standalone. **Não tem build.** Abrir o `index.html` é o
suficiente para rodar.

## Estrutura

```
index.html          o app inteiro (marcação, estilos e lógica)
supabase/schema.sql  tabelas, RPC, RLS e grants do banco
vercel.json          config de deploy estático
```

## Banco (Supabase provisionado pelo Vercel)

O app fala direto com a API REST do Supabase (PostgREST), sem SDK.

- `propostas_geradas` — histórico das propostas emitidas
- `proposta_contador` — linha única (`id = 1`) com o próximo número
- `obter_proximo_numero_proposta()` — RPC `security definer` que devolve o
  número atual e incrementa o contador numa operação só

### Provisionar

1. No painel do Vercel: **Storage → Create Database → Supabase**, e conecte ao
   projeto `gerador-orcamentos`.
2. Abra o **Supabase Studio** pelo próprio Vercel e rode `supabase/schema.sql`
   inteiro no SQL Editor.
3. Copie `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` (aba *Environment
   Variables* do banco) e cole no topo do `index.html`.

### Por que as chaves ficam no `index.html`

Como não existe etapa de build, as variáveis de ambiente do Vercel não chegam
ao navegador — não há bundler para substituí-las. A publishable key é pública
por definição; quem protege os dados é a **Row Level Security** definida em
`supabase/schema.sql`: leitura e inserção liberadas, update e delete
bloqueados, e o contador só muda através da RPC.

> Qualquer pessoa com a URL do site consegue ler o histórico de propostas.
> Se isso não for aceitável, o caminho é mover as chamadas para uma Serverless
> Function em `/api` usando `SUPABASE_SECRET_KEY` no servidor.

## Dependências de CDN

As versões são **fixas de propósito**:

```
@babel/standalone@7.28.4
react@18.3.1 / react-dom@18.3.1
```

Não voltar para `@18` ou para a tag sem versão. O Babel 8 mudou o
`preset-react` para o runtime automático, que emite
`import { jsx } from "react/jsx-runtime"` — código injetado como script
clássico, o que derruba a página inteira com *"Cannot use import statement
outside a module"*.

## Rodar local

```bash
python3 -m http.server 4188
```

E abrir <http://localhost:4188>.
