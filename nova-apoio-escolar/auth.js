/* NOVA Apoio Escolar: autenticação inicial.
 * Usa apenas a chave publishable pública da aplicação principal.
 * Não inclui service_role nem grava dados clínicos.
 * A leitura de perfis é limitada ao utilizador autenticado e depende das políticas RLS existentes.
 */
(() => {
  "use strict";
  const SUPABASE_URL = "https://rojyxfjaidyvtmsmefcf.supabase.co";
  const SUPABASE_PUBLISHABLE_KEY = "sb_publishable_NMAq5b6mRp-eD3mkbWGGgQ_PtDIzqY-";

  const screen = document.getElementById("authScreen");
  const layout = document.getElementById("appLayout");
  const form = document.getElementById("loginForm");
  const emailInput = document.getElementById("loginEmail");
  const passwordInput = document.getElementById("loginPassword");
  const loginButton = document.getElementById("loginButton");
  const message = document.getElementById("authMessage");
  const logoutButton = document.getElementById("logoutButton");
  const userLabel = document.getElementById("userLabel");
  const userAvatar = document.getElementById("userAvatar");

  let db = null;
  let busy = false;

  function showMessage(text, type = "info") {
    message.textContent = text || "";
    message.className = text ? "auth-msg " + type : "";
  }

  function setBusy(value) {
    busy = value;
    loginButton.disabled = value;
    loginButton.textContent = value ? "A verificar acesso…" : "Entrar";
    emailInput.disabled = value;
    passwordInput.disabled = value;
  }

  function showLogin(text = "", type = "info") {
    layout.classList.remove("authed");
    screen.style.display = "grid";
    setBusy(false);
    showMessage(text, type);
  }

  function showApp(profile) {
    const displayName = (profile.nome_completo || profile.email || "Utilizador").trim();
    userLabel.textContent = displayName;
    userAvatar.textContent = displayName.charAt(0).toLocaleUpperCase("pt-PT");
    screen.style.display = "none";
    layout.classList.add("authed");
    setBusy(false);
  }

  async function validateSession() {
    const { data: { user }, error: userError } = await db.auth.getUser();
    if (userError || !user) {
      await db.auth.signOut();
      showLogin();
      return;
    }

    // Consultar apenas o perfil da própria conta; não carregar dados de alunos ou registos clínicos.
    const { data: profile, error } = await db
      .from("perfis")
      .select("id,instituicao_id,nome_completo,email,role,ativo")
      .eq("id", user.id)
      .maybeSingle();

    if (error) {
      console.error("Falha ao validar o perfil NOVA:", error.code || error.message);
      showLogin("Não foi possível validar o perfil. Confirme as permissões da conta ou contacte o administrador.", "error");
      return;
    }
    if (!profile || profile.ativo !== true || !profile.instituicao_id) {
      await db.auth.signOut();
      showLogin("A conta não tem um perfil ativo associado a uma instituição. Peça ao administrador para verificar o acesso.", "error");
      return;
    }

    showApp(profile);
  }

  async function init() {
    if (!window.supabase || typeof window.supabase.createClient !== "function") {
      showLogin("Não foi possível carregar o serviço de autenticação. Verifique a ligação à internet e tente novamente.", "error");
      return;
    }

    db = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (busy) return;
      const email = emailInput.value.trim();
      const password = passwordInput.value;
      if (!email || !password) {
        showMessage("Introduza o email e a palavra-passe.", "error");
        return;
      }
      setBusy(true);
      showMessage("A autenticar e a validar as permissões…");
      try {
        const { error } = await db.auth.signInWithPassword({ email, password });
        if (error) {
          showLogin("Não foi possível iniciar sessão. Verifique as credenciais ou contacte o administrador.", "error");
          return;
        }
        await validateSession();
      } catch (error) {
        console.error("Erro de autenticação NOVA:", error && error.message);
        showLogin("O serviço de autenticação não respondeu. Tente novamente mais tarde.", "error");
      } finally {
        setBusy(false);
        passwordInput.value = "";
      }
    });

    logoutButton.addEventListener("click", async () => {
      if (!db) return;
      logoutButton.disabled = true;
      try {
        const { error } = await db.auth.signOut();
        if (error) {
          showLogin("Não foi possível terminar a sessão. Feche a janela e tente novamente.", "error");
          return;
        }
        showLogin("Sessão terminada.");
      } finally {
        logoutButton.disabled = false;
      }
    });

    db.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT") showLogin();
    });

    try {
      const { data: { session }, error } = await db.auth.getSession();
      if (error) {
        showLogin("Não foi possível verificar a sessão. Inicie sessão novamente.", "error");
        return;
      }
      if (session) await validateSession();
      else showLogin();
    } catch (error) {
      console.error("Erro ao recuperar sessão NOVA:", error && error.message);
      showLogin("Não foi possível recuperar a sessão. Tente entrar novamente.", "error");
    }
  }

  init();
})();
