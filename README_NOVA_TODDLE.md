# NOVA TODDLE ESCOLAR

Aplicação web inicial da NOVA TODDLE ESCOLAR, separada do projeto CIADI.

## Backend
- Supabase: `rojyxfjaidyvtmsmefcf`
- URL: https://rojyxfjaidyvtmsmefcf.supabase.co
- Autenticação: Supabase Auth
- Dados: tabelas escolares existentes no projeto NOVA TODDLE

## Funcionalidades desta primeira versão
- Login real por Supabase Auth
- Identificação do utilizador através de `public.perfis`
- Saudação personalizada pelo primeiro nome
- Dashboard inicial
- Contadores de alunos, professores, turmas e matrículas
- Módulos de alunos, professores, académico e comunicação
- Área NOVA AI
- Leitura protegida pelas políticas RLS existentes
- Layout responsivo para computador e telemóvel

## Separação de projetos
Este código NÃO reutiliza a arquitetura clínica do CIADI. O repositório GitHub foi utilizado apenas porque é o repositório atualmente conectado ao projeto Supabase NOVA TODDLE.

## Estado do build Windows
- Workflow: `.github/workflows/build-nova-toddle-windows.yml`
- Trigger: push na branch `nova-toddle-escolar` ou execução manual
- Artifact principal: `nova-toddle-escolar-windows-installer`
- Validação: `npm test` + `npm run check` antes do empacotamento
- Instalador: `NOVA-TODDLE-ESCOLAR-Setup-1.0.0.exe`

## Próximos passos
1. Associar a instituição ao perfil administrador.
2. Implementar cadastro/gestão de instituição.
3. Construir os dashboards completos por função.
4. Integrar a chamada real à Edge Function `nova-ai`.
5. Criar migrations/configuração Supabase no repositório para sincronização GitHub.
6. Testar Auth, RLS e fluxos de cada perfil.

## Licenciamento e controlo de pagamentos (em preparação)
- Migration aditiva: `supabase/migrations/20261028140000_license_installation_control.sql`.
- Edge Function: `supabase/functions/license-control/index.ts` (JWT obrigatório).
- Regista instalações por instituição, limita instalações ativas por assinatura e permite revogação pelo Super Admin.
- O estado da licença é validado no servidor; a chave de instalação do browser não é prova de pagamento.
- A confirmação de pagamento é manual e exclusiva do Super Admin, exige valor integral da fatura e referência do comprovativo, e regista auditoria.
- O estado `active` só deve ser atribuído depois de confirmação real do recebimento. A data de fim da assinatura deve ser validada/atualizada separadamente; confirmar uma fatura não inventa um novo período.
- A migração e a função ainda precisam de ser aplicadas/publicadas no projeto Supabase NOVA TODDLE. Não foram alterados dados de produção nem políticas existentes nesta etapa.
- A fiscalização obrigatória na web está protegida pela flag `LICENSE_ENFORCEMENT_ENABLED=false` em `index.html`; só a ativar depois de validar a migration, a Edge Function e os testes de licença, para não bloquear clientes durante uma implantação incompleta.
- Antes de ativar a fiscalização obrigatória, fazer backup e teste de restauro, validar RLS e testar trial, pagamento pendente, pagamento confirmado, expiração, limite de instalações, revogação e isolamento entre instituições.
