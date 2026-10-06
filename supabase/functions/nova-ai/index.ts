import { createClient } from "npm:@supabase/supabase-js@2";

type Body = { message?: string; conversation_id?: string; aluno_id?: string | null };

function getCorsHeaders(req: Request) {
  const origin = req.headers.get("Origin");
  const configured = (Deno.env.get("NOVA_AI_ALLOWED_ORIGINS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
  const allowed = !origin || configured.length === 0 || configured.includes("*") || configured.includes(origin);
  return {
    "Access-Control-Allow-Origin": allowed && origin ? origin : "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}
function json(data: unknown, status = 200, headers: Record<string,string> = {}) {
  return new Response(JSON.stringify(data), { status, headers: { ...headers, "Content-Type": "application/json" } });
}
Deno.serve(async (req: Request) => {
  const corsHeaders = getCorsHeaders(req);
  const origin = req.headers.get("Origin");
  const configuredOrigins = (Deno.env.get("NOVA_AI_ALLOWED_ORIGINS") ?? "").split(",").map((v) => v.trim()).filter(Boolean);
  if (origin && configuredOrigins.length > 0 && !configuredOrigins.includes("*") && !configuredOrigins.includes(origin))
    return json({ error: "Origem não autorizada." }, 403, corsHeaders);
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405, corsHeaders);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Autenticação obrigatória." }, 401, corsHeaders);
  const token = authHeader.replace("Bearer ", "").trim();
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const publishableKeys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
  const clientKey = publishableKeys.default ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!supabaseUrl || !clientKey) return json({ error: "Configuração Supabase incompleta." }, 500, corsHeaders);

  const supabase = createClient(supabaseUrl, clientKey, {
    global: { headers: { Authorization: "Bearer " + token } },
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Sessão inválida ou expirada." }, 401, corsHeaders);
  const userId = userData.user.id;

  const body = (await req.json().catch(() => ({}))) as Body;
  const message = (body.message ?? "").trim();
  if (!message) return json({ error: "A mensagem é obrigatória." }, 400, corsHeaders);
  if (message.length > 6000) return json({ error: "A mensagem excede o limite permitido." }, 400, corsHeaders);

  const { data: profile, error: profileError } = await supabase.from("perfis")
    .select("id,instituicao_id,nome_completo,role,ativo").eq("id", userId).maybeSingle();
  if (profileError || !profile || !profile.ativo) return json({ error: "Perfil escolar não encontrado ou inativo." }, 403, corsHeaders);

  const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}");
  const serviceKey = secretKeys.default ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const admin = serviceKey ? createClient(supabaseUrl, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } }) : null;
  if (!admin) return json({ error: "Configuração administrativa da NOVA AI incompleta." }, 503, corsHeaders);
  const dataClient = admin;

  await admin.from("nova_ai_rate_limits").delete().eq("perfil_id", userId)
    .lt("created_at", new Date(Date.now() - 10 * 60 * 1000).toISOString());
  const windowStart = new Date(Date.now() - 60 * 1000).toISOString();
  const { count: recentCount, error: rateReadError } = await admin.from("nova_ai_rate_limits")
    .select("id", { count: "exact", head: true }).eq("perfil_id", userId).gte("created_at", windowStart);
  if (rateReadError) return json({ error: "Não foi possível validar o limite de utilização." }, 503, corsHeaders);
  if ((recentCount ?? 0) >= 20)
    return json({ error: "Limite temporário da NOVA AI atingido. Tente novamente em instantes.", retry_after_seconds: 60 }, 429, { ...corsHeaders, "Retry-After": "60" });
  const { error: rateInsertError } = await admin.from("nova_ai_rate_limits").insert({ perfil_id: userId });
  if (rateInsertError) return json({ error: "Não foi possível registar o pedido." }, 503, corsHeaders);

  let authorizedAlunoId: string | null = null;
  let alunoContext = "";
  if (body.aluno_id) {
    const { data: aluno, error: alunoError } = await supabase.from("alunos")
      .select("id,instituicao_id,nome_completo").eq("id", body.aluno_id).maybeSingle();
    if (alunoError || !aluno || aluno.instituicao_id !== profile.instituicao_id)
      return json({ error: "Aluno não autorizado para este utilizador." }, 403, corsHeaders);
    authorizedAlunoId = aluno.id;
    alunoContext = "Aluno selecionado: " + aluno.nome_completo + ".";
  }

  const firstName = (profile.nome_completo ?? "").trim().split(/\s+/)[0] || "Utilizador";

  const { data: assistant } = await dataClient.from("ai_assistants")
    .select("id,nome,instrucoes,escopo").eq("instituicao_id", profile.instituicao_id)
    .eq("ativo", true).order("created_at", { ascending: true }).limit(1).maybeSingle();
  let assistantId = assistant?.id ?? null;
  if (!assistantId) {
    const { data: created } = await admin.from("ai_assistants").insert({
      instituicao_id: profile.instituicao_id, nome: "NOVA AI", descricao: "Assistente educacional da plataforma escolar",
      ativo: true, escopo: "educacional",
      instrucoes: "Ajudar com aprendizagem, organização escolar e orientação educacional. Não substituir professores nem fornecer decisões administrativas como se fossem oficiais.",
    }).select("id,nome,instrucoes,escopo").single();
    assistantId = created?.id ?? null;
  }
  if (!assistantId) return json({ error: "Assistente NOVA AI não configurado." }, 503, corsHeaders);

  let conversationId = body.conversation_id ?? null;
  if (conversationId) {
    const { data: existing } = await supabase.from("ai_conversas").select("id,aluno_id")
      .eq("id", conversationId).eq("perfil_id", userId).maybeSingle();
    if (!existing) conversationId = null;
    else if (authorizedAlunoId && existing.aluno_id && existing.aluno_id !== authorizedAlunoId)
      return json({ error: "O aluno selecionado não corresponde à conversa." }, 409, corsHeaders);
    else if (!authorizedAlunoId && existing.aluno_id) authorizedAlunoId = existing.aluno_id;
  }

  if (!conversationId) {
    const { data: conversation, error: conversationError } = await supabase.from("ai_conversas").insert({
      assistant_id: assistantId, perfil_id: userId, aluno_id: authorizedAlunoId, titulo: message.slice(0, 80),
    }).select("id").single();
    if (conversationError || !conversation) return json({ error: "Não foi possível criar a conversa." }, 500, corsHeaders);
    conversationId = conversation.id;
  }

  const { error: userMessageError } = await supabase.from("ai_mensagens").insert({
    conversa_id: conversationId, role: "user", conteudo: message,
  });
  if (userMessageError) return json({ error: "Não foi possível guardar a mensagem." }, 500, corsHeaders);

  const { data: knowledge } = await dataClient.from("ai_conhecimento").select("titulo,categoria,conteudo,fonte")
    .eq("instituicao_id", profile.instituicao_id).eq("ativo", true).eq("publico", true).limit(12);
  const knowledgeText = (knowledge ?? []).map((k: any) =>
    "[" + (k.categoria ?? "geral") + "] " + k.titulo + ": " + (k.conteudo ?? "").slice(0, 2500)
  ).join("\n\n");

  const systemPrompt = [
    assistant?.instrucoes ?? "És a NOVA AI, assistente educacional da plataforma escolar.",
    "O utilizador autenticado é " + profile.nome_completo + ". Trata-o pelo primeiro nome (" + firstName + ") de forma natural e cordial quando fizer sentido.",
    "Se a mensagem for uma saudação, personaliza naturalmente. Exemplo de comportamento: Bom dia, " + firstName + "! Como vai?",
    "Nunca inventes o nome do utilizador. O nome oficial vem do perfil autenticado da plataforma.",
    "Utilizador: " + (profile.nome_completo ?? "Utilizador") + "; perfil: " + profile.role + ".",
    alunoContext,
    "Responde de forma clara, educativa, segura e objetiva.",
    "Não inventes dados escolares. Quando não houver informação suficiente, diz que a informação não está disponível.",
    "Não te apresentes como representante oficial de Cambridge e não afirmes certificação ou afiliação.",
    knowledgeText ? "Base de conhecimento autorizada:\n" + knowledgeText : "",
  ].filter(Boolean).join("\n\n");

  let answer = "";
  let provider = "knowledge-fallback";
  let model: string | null = null;
  const sources: any[] = (knowledge ?? []).map((k: any) => ({ titulo: k.titulo, categoria: k.categoria, fonte: k.fonte }));

  // DeepSeek is the primary NOVA AI provider. The API key remains server-side.
  const deepseekKey = Deno.env.get("DEEPSEEK_API_KEY");
  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  const preferredProvider = (Deno.env.get("NOVA_AI_PROVIDER") ?? "deepseek").toLowerCase();

  async function callDeepSeek(): Promise<string> {
    if (!deepseekKey) return "";
    model = Deno.env.get("DEEPSEEK_MODEL") ?? "deepseek-chat";
    const response = await fetch("https://api.deepseek.com/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + deepseekKey },
      body: JSON.stringify({ model, messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: message },
      ], temperature: 0.4, max_tokens: 900 }),
    });
    if (!response.ok) return "";
    const result = await response.json();
    provider = "deepseek";
    return result?.choices?.[0]?.message?.content?.trim() ?? "";
  }

  async function callOpenAI(): Promise<string> {
    if (!openaiKey) return "";
    model = Deno.env.get("NOVA_AI_MODEL") ?? "gpt-5-mini";
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": "Bearer " + openaiKey },
      body: JSON.stringify({ model, instructions: systemPrompt, input: message, max_output_tokens: 900 }),
    });
    if (!response.ok) return "";
    const result = await response.json();
    provider = "openai";
    return result.output_text ?? "";
  }

  if (preferredProvider === "openai") {
    answer = await callOpenAI();
    if (!answer) answer = await callDeepSeek();
  } else {
    answer = await callDeepSeek();
    if (!answer) answer = await callOpenAI();
  }

  if (!answer) {
    provider = "knowledge-fallback";
    model = null;
    answer = knowledgeText
      ? "Encontrei informação na base de conhecimento da escola relacionada com a sua pergunta. Consulte as fontes apresentadas abaixo ou envie uma pergunta mais específica para eu orientar melhor."
      : "A NOVA AI está configurada e autenticada, mas a chave do provedor de IA ainda não está configurada. A base escolar e o sistema de conversas já estão preparados.";
  }

  const { error: assistantMessageError } = await supabase.from("ai_mensagens").insert({
    conversa_id: conversationId, role: "assistant", conteudo: answer, fontes: sources,
    metadata: { provider, model },
  });
  await supabase.from("ai_conversas").update({ updated_at: new Date().toISOString() }).eq("id", conversationId).eq("perfil_id", userId);

  return json({ success: true, conversation_id: conversationId, answer, sources, provider: openaiKey ? "openai" : "knowledge-fallback", user: { nome: profile.nome_completo, primeiro_nome: firstName, role: profile.role } }, 200, corsHeaders);
});