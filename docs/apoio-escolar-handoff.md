# NOVA TODDLE ESCOLAR — Apoio Escolar e Registo de Contas

Este pacote é um artefacto de revisão/entrega de código, não um instalador nem uma autorização para alterar produção.

## Incluído
- `index.html`: formulário público com seleção de Aluno, Professor, Encarregado de educação ou Formando.
- `supabase/migrations/202610160001_apoio_escolar_module.sql`: proposta do módulo Apoio Escolar, planos, progresso e políticas RLS.
- `supabase/migrations/202610160002_public_registration_roles.sql`: criação de perfis escolares inativos para pedidos de registo de aluno, professor e encarregado.
- `supabase/tests/apoio_escolar_schema.test.sql`: verificações pgTAP de esquema.
- `tests/build-smoke.test.js` e workflow de validação.

## Segurança e ativação
- As migrações não são executadas pelo workflow e não foram aplicadas à base de dados de produção.
- Os perfis de aluno/professor/encarregado são criados inativos e sem instituição; a escola tem de verificar a identidade, associar a instituição e ativar o perfil.
- O pedido de registo não cria automaticamente uma linha em `alunos`, `professores` ou `encarregados`. Essa associação deve ser feita por um fluxo administrativo validado.
- A criação de contas reais deve ser testada apenas num projeto Supabase de desenvolvimento com emails de teste.
- Antes de aplicar migrações, rever políticas RLS, testar com perfis fictícios de cada papel e preparar backup recuperável.

## Verificações incluídas
O workflow executa `npm test`, `npm run check` e a verificação sintática da função Apoio Escolar. O artefacto só é publicado se esses passos passarem. A validação SQL/pgTAP exige uma base de dados de teste com as migrações aplicadas e não é declarada como concluída por este workflow.
