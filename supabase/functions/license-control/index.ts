import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const respond = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: cors });

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return respond({ ok: false, error: "Método não permitido." }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    return respond({ ok: false, error: "Configuração segura do serviço incompleta." }, 500);
  }

  const authorization = req.headers.get("Authorization") || "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) return respond({ ok: false, error: "Autenticação necessária." }, 401);

  const authClient = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: authError } = await authClient.auth.getUser(token);
  if (authError || !userData.user) return respond({ ok: false, error: "Sessão inválida ou expirada." }, 401);

  const adminDb = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const body = await req.json();
    const action = String(body?.action || "check");
    const { data: profile, error: profileError } = await adminDb
      .from("perfis")
      .select("id, instituicao_id, role, ativo")
      .eq("id", userData.user.id)
      .maybeSingle();

    if (profileError || !profile || !profile.ativo) {
      return respond({ ok: false, valid: false, state: "denied", reason: "Perfil ativo não encontrado." }, 403);
    }

    if (action === "revoke") {
      if (profile.role !== "super_admin") {
        return respond({ ok: false, error: "Apenas o Super Admin pode revogar instalações." }, 403);
      }
      const recordId = String(body?.installation_record_id || "");
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(recordId)) {
        return respond({ ok: false, error: "Identificador de instalação inválido." }, 400);
      }
      const { data: row, error: readError } = await adminDb
        .from("plataforma_instalacoes").select("id,instituicao_id,status")
        .eq("id", recordId).maybeSingle();
      if (readError || !row) return respond({ ok: false, error: "Instalação não encontrada." }, 404);
      const { error: updateError } = await adminDb.from("plataforma_instalacoes")
        .update({ status: "revoked", revoked_at: new Date().toISOString(), revoked_by: userData.user.id, updated_at: new Date().toISOString() })
        .eq("id", recordId);
      if (updateError) return respond({ ok: false, error: "Não foi possível revogar a instalação." }, 500);
      await adminDb.from("plataforma_licenca_eventos").insert({
        instituicao_id: row.instituicao_id, instalacao_id: row.id, evento: "revogada",
        estado: "revoked", motivo: String(body?.reason || "Revogada pelo Super Admin").slice(0, 500),
        ator_id: userData.user.id,
      });
      return respond({ ok: true, state: "revoked" });
    }

    let institutionId = profile.instituicao_id as string | null;
    if (profile.role === "super_admin" && body?.instituicao_id) {
      institutionId = String(body.instituicao_id);
    }
    if (!institutionId) {
      return respond({ ok: false, valid: false, state: "unassigned", reason: "O utilizador ainda não está associado a uma escola." }, 403);
    }

    const { data: institution, error: institutionError } = await adminDb
      .from("instituicao").select("id,nome,status,data_expiracao")
      .eq("id", institutionId).maybeSingle();
    if (institutionError || !institution) return respond({ ok: false, valid: false, state: "denied", reason: "Instituição não encontrada." }, 404);

    const { data: subscription, error: subscriptionError } = await adminDb
      .from("plataforma_assinaturas")
      .select("id,estado,inicio,fim,limite_instalacoes,created_at")
      .eq("instituicao_id", institutionId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (subscriptionError) return respond({ ok: false, valid: false, state: "unavailable", reason: "Não foi possível validar a licença." }, 503);

    const now = new Date();
    const today = now.toISOString().slice(0, 10);
    const expires = subscription?.fim || institution.data_expiracao || null;
    const status = String(subscription?.estado || institution.status || "suspended").toLowerCase();
    const institutionStatus = String(institution.status || "").toLowerCase();
    const dateValid = !!expires && expires >= today;
    const stateValid = status === "active" || status === "trial";
    const institutionValid = institutionStatus === "active" || institutionStatus === "trial";
    const valid = !!subscription && stateValid && institutionValid && dateValid;
    const reason = !subscription ? "Não existe assinatura associada à instituição."
      : !stateValid ? "A assinatura não está ativa. Confirme o pagamento ou regularize a licença."
      : !institutionValid ? "A instituição está suspensa ou expirada."
      : !dateValid ? "A licença expirou ou não tem data de validade definida."
      : null;

    const limit = Math.max(1, Number(subscription?.limite_instalacoes || 1));
    const installationId = String(body?.installation_id || "");
    let installation = null;
    let activeCount = 0;

    if (installationId && !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(installationId)) {
      return respond({ ok: false, valid: false, state: "denied", reason: "Identificador da instalação inválido." }, 400);
    }

    const { count, error: countError } = await adminDb.from("plataforma_instalacoes")
      .select("id", { count: "exact", head: true })
      .eq("instituicao_id", institutionId).eq("status", "active");
    if (countError) return respond({ ok: false, valid: false, state: "unavailable", reason: "O controlo de instalações ainda não está configurado. Contacte o suporte." }, 503);
    activeCount = count || 0;

    if (installationId) {
      const { data: existing, error: existingError } = await adminDb.from("plataforma_instalacoes")
        .select("id,status,device_name,platform,app_version")
        .eq("instituicao_id", institutionId).eq("installation_id", installationId).maybeSingle();
      if (existingError) return respond({ ok: false, valid: false, state: "unavailable", reason: "Não foi possível consultar a instalação." }, 503);
      installation = existing;
    }

    if (action === "register") {
      if (!valid) {
        await adminDb.from("plataforma_licenca_eventos").insert({
          instituicao_id: institutionId, evento: "negada", estado: status, motivo: reason,
          ator_id: userData.user.id,
        });
        return respond({ ok: false, valid: false, state: status, reason, expires_at: expires }, 403);
      }
      if (!installationId) return respond({ ok: false, error: "Falta o identificador da instalação." }, 400);
      if (installation?.status === "revoked") {
        return respond({ ok: false, valid: false, state: "revoked", reason: "Esta instalação foi revogada. Contacte o suporte." }, 403);
      }
      if (!installation && activeCount >= limit) {
        return respond({ ok: false, valid: false, state: "install_limit", reason: `Limite de instalações atingido (${limit}).`, installations_used: activeCount, installations_limit: limit }, 403);
      }
      const payload = {
        instituicao_id: institutionId,
        installation_id: installationId,
        device_name: String(body?.device_name || "Instalação web").slice(0, 120),
        platform: String(body?.platform || "web").slice(0, 40),
        app_version: String(body?.app_version || "web").slice(0, 40),
        status: "active",
        last_seen: now.toISOString(),
        updated_at: now.toISOString(),
      };
      const { data: saved, error: saveError } = await adminDb.from("plataforma_instalacoes")
        .upsert(payload, { onConflict: "instituicao_id,installation_id" })
        .select("id,status,last_seen").single();
      if (saveError) return respond({ ok: false, valid: false, state: "unavailable", reason: "Não foi possível registar a instalação." }, 503);
      await adminDb.from("plataforma_licenca_eventos").insert({
        instituicao_id: institutionId, instalacao_id: saved.id,
        evento: installation ? "validada" : "registada", estado: status,
        motivo: "Validação de licença concluída.", ator_id: userData.user.id,
      });
      return respond({ ok: true, valid: true, state: status, institution: institution.nome, expires_at: expires, installations_used: installation ? activeCount : activeCount + 1, installations_limit: limit, installation: saved });
    }

    if (action !== "check") return respond({ ok: false, error: "Ação não suportada." }, 400);
    if (!valid) return respond({ ok: true, valid: false, state: status, reason, expires_at: expires, installations_used: activeCount, installations_limit: limit }, 200);
    if (installationId && (!installation || installation.status !== "active")) {
      return respond({ ok: true, valid: false, state: installation?.status || "not_registered", reason: "Esta instalação não está registada ou foi revogada.", expires_at: expires, installations_used: activeCount, installations_limit: limit }, 200);
    }

    if (installationId && installation) {
      await adminDb.from("plataforma_instalacoes").update({ last_seen: now.toISOString(), updated_at: now.toISOString() })
        .eq("instituicao_id", institutionId).eq("installation_id", installationId).eq("status", "active");
    }
    await adminDb.from("plataforma_licenca_eventos").insert({
      instituicao_id: institutionId, instalacao_id: installation?.id || null,
      evento: "validada", estado: status, motivo: "Verificação de licença concluída.", ator_id: userData.user.id,
    });
    return respond({ ok: true, valid: true, state: status, institution: institution.nome, expires_at: expires, installations_used: activeCount, installations_limit: limit });
  } catch {
    return respond({ ok: false, error: "Pedido de licença inválido." }, 400);
  }
});
