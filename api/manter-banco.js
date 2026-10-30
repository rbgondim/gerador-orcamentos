// Mantem o projeto Supabase (plano gratuito) acordado.
//
// O Supabase pausa projetos gratuitos que passam ~7 dias sem atividade de
// banco. Esta funcao e um dos DOIS agendamentos que tocam o banco (o outro e
// o GitHub Actions, .github/workflows/manter-banco.yml, a cada 6h): a Vercel
// chama uma vez por dia, que e o maximo do plano Hobby.
//
// Cada chamada GRAVA uma linha via RPC registrar_ping (escrita conta como
// atividade com mais certeza que leitura) e deixa historico em
// public.manter_acordado com a origem — e assim que da pra saber se a Vercel
// esta mesmo chamando. Se a RPC ainda nao existir no banco, cai numa leitura.
//
// Nunca chama obter_proximo_numero_proposta: ela incrementa a numeracao.

const SUPABASE_URL = process.env.SUPABASE_URL || "https://juohkexddpvcrzugjjud.supabase.co";
// a publishable key ja e publica (esta no index.html); a env var, se existir, tem prioridade
const SUPABASE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_k2l_n-Jg4oJ2jj5bpbX3wg_Gbf-3aJK";

module.exports = async (req, res) => {
  const segredo = process.env.CRON_SECRET;
  if (segredo && req.headers.authorization !== `Bearer ${segredo}`) {
    return res.status(401).json({ ok: false, erro: "nao autorizado" });
  }

  // a Vercel manda "vercel-cron/1.0" no user agent; chamada manual fica "manual"
  const origem = /vercel-cron/i.test(req.headers["user-agent"] || "") ? "vercel" : "manual";
  const cab = { apikey: SUPABASE_KEY, "Content-Type": "application/json" };
  const inicio = Date.now();

  try {
    let r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/registrar_ping`, {
      method: "POST", headers: cab, body: JSON.stringify({ p_origem: origem }),
    });
    let modo = "escrita";
    if (r.status === 404) {
      // migracao 005 ainda nao rodou: pelo menos uma leitura real
      modo = "leitura (rode a migracao 005)";
      r = await fetch(`${SUPABASE_URL}/rest/v1/proposta_contador?select=proximo_numero&id=eq.1`, { headers: cab });
    }
    const corpo = await r.text();
    if (!r.ok) throw new Error(`HTTP ${r.status}: ${corpo.slice(0, 200)}`);
    const resultado = { ok: true, modo, origem, ms: Date.now() - inicio, em: new Date().toISOString() };
    console.log("banco acordado", resultado);
    return res.status(200).json(resultado);
  } catch (e) {
    // 502 aparece como falha no log da Vercel — sinal de que o projeto
    // ja pausou e precisa ser restaurado no painel do Supabase
    const resultado = { ok: false, origem, erro: String(e.message || e).slice(0, 300), ms: Date.now() - inicio, em: new Date().toISOString() };
    console.error("banco nao respondeu", resultado);
    return res.status(502).json(resultado);
  }
};
