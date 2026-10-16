-- NOVA TODDLE ESCOLAR: Apoio Escolar (proposta, não aplicada à produção)
-- Rever com os responsáveis antes de aplicar. A migração é aditiva e mantém os dados existentes.
alter table public.solicitacoes_apoio_escolar
  add column if not exists aluno_id uuid references public.alunos(id),
  add column if not exists encarregado_id uuid references public.encarregados(id);

-- Split the existing ALL policy: a permissive ALL policy would also grant SELECT to finance/reception roles.
drop policy if exists "tenant manage solicitacoes_apoio_escolar" on public.solicitacoes_apoio_escolar;
create policy "apoio request tenant insert managers"
on public.solicitacoes_apoio_escolar for insert to authenticated
with check (
  (
  private.is_super_admin()
  or (
    instituicao_id = private.current_institution_id()
    and exists (
      select 1 from public.perfis p
      where p.id = (select auth.uid())
        and p.ativo = true
        and p.instituicao_id = private.current_institution_id()
        and p.role in ('school_admin','principal','academic_director')
    )
  )
)
  and exists (
    select 1 from public.alunos a
    where a.id = solicitacoes_apoio_escolar.aluno_id
      and a.instituicao_id = solicitacoes_apoio_escolar.instituicao_id
  )
);
create policy "apoio request tenant update managers"
on public.solicitacoes_apoio_escolar for update to authenticated
using ((
  private.is_super_admin()
  or (
    instituicao_id = private.current_institution_id()
    and exists (
      select 1 from public.perfis p
      where p.id = (select auth.uid())
        and p.ativo = true
        and p.instituicao_id = private.current_institution_id()
        and p.role in ('school_admin','principal','academic_director')
    )
  )
))
with check (
  (
  private.is_super_admin()
  or (
    instituicao_id = private.current_institution_id()
    and exists (
      select 1 from public.perfis p
      where p.id = (select auth.uid())
        and p.ativo = true
        and p.instituicao_id = private.current_institution_id()
        and p.role in ('school_admin','principal','academic_director')
    )
  )
)
  and exists (
    select 1 from public.alunos a
    where a.id = solicitacoes_apoio_escolar.aluno_id
      and a.instituicao_id = solicitacoes_apoio_escolar.instituicao_id
  )
);
create policy "apoio request tenant delete managers"
on public.solicitacoes_apoio_escolar for delete to authenticated
using ((
  private.is_super_admin()
  or (
    instituicao_id = private.current_institution_id()
    and exists (
      select 1 from public.perfis p
      where p.id = (select auth.uid())
        and p.ativo = true
        and p.instituicao_id = private.current_institution_id()
        and p.role in ('school_admin','principal','academic_director')
    )
  )
));

-- Replace the broad tenant SELECT policy so family profiles cannot enumerate all requests.
drop policy if exists "tenant select solicitacoes_apoio_escolar" on public.solicitacoes_apoio_escolar;
create policy "apoio request staff select tenant"
on public.solicitacoes_apoio_escolar for select to authenticated
using (
  private.is_super_admin()
  or (instituicao_id = private.current_institution_id()
      and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
);

-- Family access is limited to a linked child and the academic-view flag.
create policy "apoio request staff insert tenant"
on public.solicitacoes_apoio_escolar for insert to authenticated
with check (
  solicitado_por = (select auth.uid())
  and instituicao_id = private.current_institution_id()
  and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  )
  and exists (
    select 1 from public.alunos a
    where a.id = solicitacoes_apoio_escolar.aluno_id
      and a.instituicao_id = solicitacoes_apoio_escolar.instituicao_id
  )
);

create policy "apoio request family select linked child"
on public.solicitacoes_apoio_escolar for select to authenticated
using (
  exists (
    select 1
    from public.encarregados e
    join public.aluno_encarregado ae on ae.encarregado_id = e.id
    where e.id = solicitacoes_apoio_escolar.encarregado_id
      and e.perfil_id = (select auth.uid())
      and ae.aluno_id = solicitacoes_apoio_escolar.aluno_id
      and ae.pode_ver_academico
  )
);

create policy "apoio request family insert linked child"
on public.solicitacoes_apoio_escolar for insert to authenticated
with check (
  solicitado_por = (select auth.uid())
  and exists (
    select 1
    from public.alunos a
    join public.aluno_encarregado ae on ae.aluno_id = a.id
    join public.encarregados e on e.id = ae.encarregado_id
    where a.id = solicitacoes_apoio_escolar.aluno_id
      and a.instituicao_id = solicitacoes_apoio_escolar.instituicao_id
      and e.id = solicitacoes_apoio_escolar.encarregado_id
      and e.perfil_id = (select auth.uid())
      and ae.pode_ver_academico
  )
);

create table if not exists public.planos_apoio_escolar (
  id uuid primary key default gen_random_uuid(),
  instituicao_id uuid not null references public.instituicao(id),
  solicitacao_id uuid references public.solicitacoes_apoio_escolar(id) on delete set null,
  aluno_id uuid not null references public.alunos(id),
  responsavel_id uuid references public.perfis(id),
  titulo text not null,
  objetivos jsonb not null default '[]'::jsonb,
  estrategias text,
  data_inicio date,
  data_revisao date,
  estado text not null default 'ATIVO' check (estado in ('RASCUNHO','ATIVO','EM_REVISAO','CONCLUIDO','SUSPENSO')),
  criado_por uuid references public.perfis(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.progresso_apoio_escolar (
  id uuid primary key default gen_random_uuid(),
  instituicao_id uuid not null references public.instituicao(id),
  plano_id uuid not null references public.planos_apoio_escolar(id) on delete cascade,
  aluno_id uuid not null references public.alunos(id),
  registado_por uuid references public.perfis(id),
  data_registo date not null default current_date,
  objetivo text not null,
  resultado text not null check (resultado in ('ALCANCADO','EM_PROGRESSO','SEM_PROGRESSO','NAO_AVALIADO')),
  observacao text,
  visivel_familia boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.planos_apoio_escolar enable row level security;
alter table public.progresso_apoio_escolar enable row level security;

revoke all on public.planos_apoio_escolar from anon;
revoke all on public.progresso_apoio_escolar from anon;
grant select, insert, update, delete on public.planos_apoio_escolar to authenticated;
grant select, insert, update, delete on public.progresso_apoio_escolar to authenticated;

create policy "apoio plans select tenant"
on public.planos_apoio_escolar for select to authenticated
using (
  private.is_super_admin()
  or (instituicao_id = private.current_institution_id()
      and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
  or exists (
    select 1 from public.aluno_encarregado ae
    where ae.aluno_id = planos_apoio_escolar.aluno_id
      and ae.encarregado_id in (select e.id from public.encarregados e where e.perfil_id = (select auth.uid()))
      and ae.pode_ver_academico
  )
);

create policy "apoio plans insert staff"
on public.planos_apoio_escolar for insert to authenticated
with check (
  (
    private.is_super_admin()
    or (instituicao_id = private.current_institution_id() and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
  )
  and exists (
    select 1 from public.alunos a
    where a.id = planos_apoio_escolar.aluno_id
      and a.instituicao_id = planos_apoio_escolar.instituicao_id
  )
);

create policy "apoio plans update staff"
on public.planos_apoio_escolar for update to authenticated
using (
  private.is_super_admin()
  or (instituicao_id = private.current_institution_id() and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
)
with check (
  (
    private.is_super_admin()
    or (instituicao_id = private.current_institution_id() and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
  )
  and exists (
    select 1 from public.alunos a
    where a.id = planos_apoio_escolar.aluno_id
      and a.instituicao_id = planos_apoio_escolar.instituicao_id
  )
);

create policy "apoio plans delete staff"
on public.planos_apoio_escolar for delete to authenticated
using (
  private.is_super_admin()
  or (instituicao_id = private.current_institution_id()
      and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
);

create policy "apoio progress select tenant"
on public.progresso_apoio_escolar for select to authenticated
using (
  private.is_super_admin()
  or (instituicao_id = private.current_institution_id()
      and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  ))
  or (
    visivel_familia
    and exists (
      select 1 from public.aluno_encarregado ae
      where ae.aluno_id = progresso_apoio_escolar.aluno_id
        and ae.encarregado_id in (select e.id from public.encarregados e where e.perfil_id = (select auth.uid()))
        and ae.pode_ver_academico
    )
  )
);

create policy "apoio progress insert staff"
on public.progresso_apoio_escolar for insert to authenticated
with check (
  instituicao_id = private.current_institution_id()
  and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  )
  and exists (
    select 1
    from public.planos_apoio_escolar pa
    join public.alunos a on a.id = pa.aluno_id
    where pa.id = progresso_apoio_escolar.plano_id
      and pa.aluno_id = progresso_apoio_escolar.aluno_id
      and pa.instituicao_id = progresso_apoio_escolar.instituicao_id
      and a.instituicao_id = progresso_apoio_escolar.instituicao_id
  )
);

create policy "apoio progress update staff"
on public.progresso_apoio_escolar for update to authenticated
using (
  instituicao_id = private.current_institution_id()
  and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  )
)
with check (
  instituicao_id = private.current_institution_id()
  and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  )
  and exists (
    select 1
    from public.planos_apoio_escolar pa
    join public.alunos a on a.id = pa.aluno_id
    where pa.id = progresso_apoio_escolar.plano_id
      and pa.aluno_id = progresso_apoio_escolar.aluno_id
      and pa.instituicao_id = progresso_apoio_escolar.instituicao_id
      and a.instituicao_id = progresso_apoio_escolar.instituicao_id
  )
);

create policy "apoio progress delete staff"
on public.progresso_apoio_escolar for delete to authenticated
using (
  instituicao_id = private.current_institution_id()
  and exists (
    select 1 from public.perfis p
    where p.id = (select auth.uid())
      and p.ativo = true
      and p.instituicao_id = private.current_institution_id()
      and p.role in ('school_admin','principal','academic_director','teacher','staff')
  )
);

create index if not exists idx_apoio_planos_tenant_aluno
  on public.planos_apoio_escolar (instituicao_id, aluno_id, estado);
create index if not exists idx_apoio_progresso_tenant_aluno_data
  on public.progresso_apoio_escolar (instituicao_id, aluno_id, data_registo desc);
