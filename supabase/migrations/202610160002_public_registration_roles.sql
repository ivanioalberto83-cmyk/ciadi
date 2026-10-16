-- NOVA TODDLE SCHOOL: registo público de aluno, professor e encarregado.
-- Proposta para revisão; NÃO aplicar em produção sem validação e backup.
-- As contas escolares ficam inativas e sem instituição até aprovação/associação pela escola.
create or replace function private.ensure_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  requested_role text;
begin
  requested_role := coalesce(new.raw_user_meta_data->>'requested_role', '');

  if requested_role not in ('student', 'teacher', 'parent') then
    return new;
  end if;

  insert into public.perfis (
    id, instituicao_id, nome_completo, email, telefone, role, ativo
  )
  values (
    new.id,
    null,
    coalesce(nullif(new.raw_user_meta_data->>'nome_completo',''), split_part(new.email,'@',1)),
    new.email,
    nullif(new.raw_user_meta_data->>'telefone',''),
    requested_role::public.user_role,
    false
  )
  on conflict (id) do nothing;

  return new;
end;
$function$;

drop trigger if exists trg_auth_user_school_profile on auth.users;
create trigger trg_auth_user_school_profile
after insert on auth.users
for each row execute function private.ensure_profile_from_auth();

-- The existing upsert targets perfil_id; ensure the target has a unique constraint.
-- A partial index preserves legacy rows that may not be linked to auth profiles.
create unique index if not exists ux_formandos_perfil_id_not_null
  on public.formandos (perfil_id) where perfil_id is not null;

-- Preserve the existing course-formando workflow; do not create a course learner
-- record for accounts explicitly registering as a school user.
create or replace function private.ensure_formando_from_auth()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if coalesce(new.raw_user_meta_data->>'requested_role', '') in ('student', 'teacher', 'parent') then
    return new;
  end if;

  insert into public.formandos (
    instituicao_id, perfil_id, nome_completo, email, telefone,
    data_nascimento, nif, documento_identificacao, provincia, municipio, morada, estado
  )
  values (
    null,
    new.id,
    coalesce(new.raw_user_meta_data->>'nome_completo', split_part(new.email,'@',1), 'Formando'),
    new.email,
    nullif(new.raw_user_meta_data->>'telefone',''),
    nullif(new.raw_user_meta_data->>'data_nascimento','')::date,
    nullif(new.raw_user_meta_data->>'nif',''),
    nullif(new.raw_user_meta_data->>'documento_identificacao',''),
    nullif(new.raw_user_meta_data->>'provincia',''),
    nullif(new.raw_user_meta_data->>'municipio',''),
    nullif(new.raw_user_meta_data->>'morada',''),
    'ATIVO'
  )
  on conflict (perfil_id) where perfil_id is not null do update set
    email = excluded.email,
    nome_completo = excluded.nome_completo,
    telefone = coalesce(excluded.telefone, public.formandos.telefone),
    data_nascimento = coalesce(excluded.data_nascimento, public.formandos.data_nascimento),
    nif = coalesce(excluded.nif, public.formandos.nif),
    documento_identificacao = coalesce(excluded.documento_identificacao, public.formandos.documento_identificacao),
    provincia = coalesce(excluded.provincia, public.formandos.provincia),
    municipio = coalesce(excluded.municipio, public.formandos.municipio),
    morada = coalesce(excluded.morada, public.formandos.morada);

  return new;
end;
$function$;
