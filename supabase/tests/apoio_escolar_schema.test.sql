-- pgTAP smoke assertions for the Apoio Escolar schema.
-- Run only after the migration is reviewed and applied to a development/test database.
begin;
select plan(6);
select has_table('public', 'solicitacoes_apoio_escolar', 'requests table exists');
select has_table('public', 'planos_apoio_escolar', 'support plans table exists');
select has_table('public', 'progresso_apoio_escolar', 'progress table exists');
select col_is_null('public', 'solicitacoes_apoio_escolar', 'aluno_id', 'request student link is optional for legacy rows');
select col_is_null('public', 'solicitacoes_apoio_escolar', 'encarregado_id', 'request guardian link is optional for legacy rows');
select ok((select relrowsecurity from pg_class where oid='public.planos_apoio_escolar'::regclass), 'plans table has RLS enabled');
select * from finish();
rollback;
