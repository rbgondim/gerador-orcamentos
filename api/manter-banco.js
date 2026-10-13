// Mantem o projeto Supabase (plano gratuito) acordado.
//
// O Supabase pausa projetos gratuitos que passam ~7 dias sem atividade de
// banco. A Vercel chama esta funcao uma vez por dia (ver "crons" no
// vercel.json — no plano Hobby o minimo e diario) e ela faz uma consulta
// REAL ao Postgres. Nao serve pingar /auth/v1/health nem provocar erro de
// schema: essas respostas saem sem tocar o banco e nao contam como atividade.
//
// So leitura. Nao chama a RPC do contador — ela incrementa a numeracao.

const SUPABASE_URL = process.env.SUPABASE_URL || "https://juohkexddpvcrzugjjud.supabase.co";
// a publishable key ja e publica (esta no index.html); a env var, se existir, tem prioridade
const SUPABASE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY || "sb_publishable_k2l_n-Jg4oJ2jj5bpbX3wg_Gbf-3aJK";

module.exports = async (req, res) => {
  // Se CRON_SECRET estiver configurado na Vercel, so a propria Vercel chama.
  // Sem ele a rota fica aberta — o que ela faz e uma leitura, entao tudo bem.
  const segredo = process.env.CRON_SECRET;
  if (segredo && req.headers.authorization !== `Bearer ${segredo}`) {
    return res.status(401).json({ ok: false, erro: "nao autorizado" });
  }

  const inicio = Date.now();
  try {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/proposta_contador?select=proximo_numero&id=eq.1`, {
      headers: { apikey: SUPABASE_KEY },
    });
    const corpo = await r.text();
    if (!r.ok) throw new Error(`HTTP ${r.status}: ${corpo.slice(0, 200)}`);
    const linhas = JSON.parse(corpo);
    const resultado = { ok: true, linhas: linhas.length, ms: Date.now() - inicio, em: new Date().toISOString() };
    console.log("banco acordado", resultado);
    return res.status(200).json(resultado);
  } catch (e) {
    // 502 aparece como falha no log da Vercel — e o sinal de que o projeto
    // ja pausou e precisa ser restaurado no painel do Supabase
    const resultado = { ok: false, erro: String(e.message || e), ms: Date.now() - inicio, em: new Date().toISOString() };
    console.error("banco nao respondeu", resultado);
    return res.status(502).json(resultado);
  }
};
