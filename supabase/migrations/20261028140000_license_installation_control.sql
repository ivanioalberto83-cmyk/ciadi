-- NOVA TODDLE ESCOLAR: controlo de licenças e instalações
-- Aditivo e reversível: não altera dados existentes nem ativa licenças automaticamente.
begin;

alter table public.plataforma_assinaturas
  add column if not exists limite_instalacoes integer not null default 1;

alter table public.plataforma_assinaturas
  drop constraint if exists plataforma_assinaturas_limite_instalacoes_check;
alter table public.plataforma_assinaturas
  add constraint plataforma_assinaturas_limite_instalacoes_check
  check (limite_instalacoes >= 1 and limite_instalacoes <= 100);

create table if not exists public.plataforma_instalacoes (
  id uuid primary key default gen_random_uuid(),
  instituicao_id uuid not null references public.instituicao(id) on delete restrict,
  installation_id uuid not null,
  device_name text not null default 'Instalação sem nome',
  platform text not null default 'web',
  app_version text,
  status text not null default 'active'
    check (status in ('active','revoked')),
  first_seen timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (instituicao_id, installation_id)
);

create index if not exists plataforma_instalacoes_tenant_status_idx
  on public.plataforma_instalacoes (instituicao_id, status, last_seen desc);

create table if not exists public.plataforma_licenca_eventos (
  id uuid primary key default gen_random_uuid(),
  instituicao_id uuid not null references public.instituicao(id) on delete restrict,
  instalacao_id uuid references public.plataforma_instalacoes(id) on delete set null,
  evento text not null check (evento in ('registada','validada','negada','revogada','pagamento_confirmado','licenca_ativada','licenca_suspensa')),
  estado text,
  motivo text,
  ator_id uuid references auth.users(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists plataforma_licenca_eventos_tenant_created_idx
  on public.plataforma_licenca_eventos (instituicao_id, created_at desc);

alter table public.plataforma_instalacoes enable row level security;
alter table public.plataforma_licenca_eventos enable row level security;

drop policy if exists "tenant admins read own installations" on public.plataforma_instalacoes;
create policy "tenant admins read own installations"
  on public.plataforma_instalacoes
  for select to authenticated
  using (
    instituicao_id = (select private.current_institution_id())
    and (select private.is_tenant_admin())
  );

drop policy if exists "super admins manage installations" on public.plataforma_instalacoes;
create policy "super admins manage installations"
  on public.plataforma_instalacoes
  for all to authenticated
  using ((select private.is_super_admin()))
  with check ((select private.is_super_admin()));

drop policy if exists "super admins read license events" on public.plataforma_licenca_eventos;
create policy "super admins read license events"
  on public.plataforma_licenca_eventos
  for select to authenticated
  using ((select private.is_super_admin()));

-- No direct tenant writes to license state; the Edge Function uses service_role
-- only after validating the caller's JWT, role, tenant and subscription.
revoke insert, update, delete on public.plataforma_instalacoes from anon, authenticated;
revoke insert, update, delete on public.plataforma_licenca_eventos from anon, authenticated;
grant select on public.plataforma_instalacoes to authenticated;
grant select on public.plataforma_licenca_eventos to authenticated;

commit;
