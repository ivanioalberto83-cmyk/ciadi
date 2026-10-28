# NOVA TODDLE ESCOLAR — Plano de Cibersegurança e Backups

> Para execução por etapas: cada tarefa exige evidência de teste e revisão antes de avançar. Este plano não autoriza alterações no ambiente de produção.

**Objetivo:** reduzir riscos de acesso indevido e estabelecer cópias de segurança recuperáveis para a aplicação, a base de dados e os ficheiros da NOVA TODDLE ESCOLAR.

**Arquitetura:** primeiro endurecer identidade, permissões, isolamento multi-instituição e funções privilegiadas num ambiente de homologação. Só depois desenhar e testar backups cifrados da base de dados, Storage e configuração, com cópia externa, manifesto de integridade e ensaio documentado de restauro.

**Tecnologias observadas:** Supabase Auth/Postgres/RLS/Storage/Edge Functions, GitHub, Electron/Windows e GitHub Actions. Os caminhos de scripts de backup são propostas novas, não foram encontrados nem validados neste ramo.

## Restrições globais

- Não executar DDL/DML, migrações, alterações de políticas RLS, alteração de Auth, nem restauros em produção sem autorização explícita.
- Não guardar chaves service_role, tokens, palavras-passe, dados de alunos ou ficheiros pessoais no GitHub, logs ou manifestos.
- Usar instituições, contas, alunos, colaboradores, documentos e pagamentos fictícios num projeto de teste isolado.
- Não assumir que um backup da base de dados inclui os objetos binários do Supabase Storage.
- Não declarar um backup válido até confirmar tamanho, checksum, conteúdo e um restauro de teste.
- Não distribuir o instalador Windows nem publicar alterações como resultado deste plano.

---

## Fase A — Cibersegurança (antes dos backups)

### Tarefa A1 — Inventário e triagem dos alertas Supabase

**Ficheiros propostos:**
- Criar: docs/security/SECURITY_FINDINGS_NOVA_TODDLE.md
- Evidência: exportação datada dos advisors de segurança e inventário de políticas, sem segredos nem dados pessoais.

- [ ] Registar cada finding com objeto afetado, severidade, evidência, impacto, responsável e teste de aceitação.
- [ ] Confirmar os 6 objetos com RLS ativo e sem políticas: acompanhamentos_rede_educacao, contratos_profissionais_nova, documentos_candidatura_profissional, historico_verificacao_profissional, pagamentos_rede_educacao e propostas_apoio_educacional. Determinar se o bloqueio é intencional; não criar políticas por suposição.
- [ ] Rever as 5 funções SECURITY DEFINER sinalizadas para authenticated: fiscal_emitir_documento, nova_atualizar_estado_cobranca, nova_criar_cobranca, nova_registar_pagamento e nova_vincular_documento_cobranca. Verificar validação interna, search_path, instituição, autorização por função e idempotência antes de propor alterações.
- [ ] Registar que a proteção contra palavras-passe comprometidas está desativada e avaliar ativação em homologação, incluindo impacto no login e recuperação.
- [ ] Critério de aprovação: cada finding tem decisão fundamentada (corrigir, aceite com justificação ou falso positivo) e evidência reproduzível.

### Tarefa A2 — Isolamento multi-instituição e controlo de papéis

**Ficheiros propostos:**
- Criar: tests/security/tenant-isolation-test-plan.md
- Rever, sem alterar inicialmente: políticas RLS e funções SQL existentes.

- [ ] Definir a matriz de permissões para super_admin, administrador escolar, direção, contabilista, receção, funcionário, professor, encarregado e formando.
- [ ] Preparar duas instituições fictícias e contas separadas por papel.
- [ ] Testar SELECT/INSERT/UPDATE/DELETE, RPC e Storage entre instituições; os testes negativos devem devolver zero linhas ou erro de autorização, sem revelar dados da outra instituição.
- [ ] Testar especialmente perfis.role e perfis.instituicao_id, gestão de professores e aluno_encarregado; nenhum utilizador pode elevar o próprio papel nem mover o próprio perfil para outra instituição.
- [ ] Rever cada consumidor de private.is_tenant_admin(); não estreitar a função auxiliar sem rever as políticas dependentes.
- [ ] Critério de aprovação: todos os testes de acesso cruzado falham de forma segura e os fluxos autorizados continuam a funcionar.

### Tarefa A3 — Autenticação, segredos e superfície da aplicação

**Ficheiros propostos:**
- Rever: index.html, electron/main.js, supabase/functions/nova-ai/index.ts, .github/workflows/build-nova-toddle-windows.yml.
- Criar: docs/security/INCIDENT_RESPONSE_NOVA_TODDLE.md.

- [ ] Verificar allowlist de Redirect URLs e entrega de recuperação de palavra-passe em ambiente de teste.
- [ ] Avaliar MFA para contas administrativas, proteção contra palavras-passe comprometidas, sessões e desativação de contas.
- [ ] Confirmar que segredos só existem no gestor de segredos adequado; procurar segredos acidentalmente versionados sem imprimir os seus valores.
- [ ] Configurar e testar a allowlist explícita de NOVA_AI_ALLOWED_ORIGINS; não permitir wildcard em produção.
- [ ] Rever minimização de dados enviados a fornecedores externos de IA, retenção, logs e consentimento/base legal aplicável.
- [ ] Rever permissões de GitHub Actions, dependências npm, política Electron e exposição de dados em logs.
- [ ] Definir resposta a incidentes: triagem, contenção, preservação de evidência, rotação de credenciais, comunicação e recuperação.
- [ ] Critério de aprovação: testes de Auth e segurança passam; nenhum segredo é incluído no repositório; cada risco residual é registado.

---

## Fase B — Sistema de backups (só após a Fase A)

### Tarefa B1 — Política de backup e objetivos de recuperação

**Ficheiro proposto:** docs/backup/BACKUP_POLICY_NOVA_TODDLE.md.

- [ ] Inventariar dados Postgres, objetos Storage, configuração de Auth, Edge Functions, definições necessárias e artefactos de lançamento.
- [ ] Distinguir backups nativos do fornecedor, exportação lógica Postgres e cópia de Storage; não assumir que um substitui os outros.
- [ ] Proposta inicial para aprovação: cópia lógica diária da base de dados, inventário incremental/diário dos objetos Storage, cópia externa cifrada e retenção de 30 dias; definir separadamente retenção mensal e custo antes de ativar.
- [ ] Definir objetivos a aprovar: RPO (perda máxima de dados aceitável) e RTO (tempo máximo para recuperação). Não assumir valores finais sem decisão do responsável.
- [ ] Confirmar limites e disponibilidade de PITR/backups geridos no plano Supabase atual antes de depender dessa funcionalidade.
- [ ] Critério de aprovação: política, custos, retenção, RPO/RTO e localização da cópia externa aprovados antes da automatização.

### Tarefa B2 — Cópias seguras e manifesto de integridade

**Caminhos propostos (não existentes/validados nesta auditoria):**
- Criar: scripts/backup/backup-postgres.ps1
- Criar: scripts/backup/backup-storage.ps1
- Criar: scripts/backup/verify-backup.ps1
- Criar: docs/backup/RESTORE_RUNBOOK_NOVA_TODDLE.md

- [ ] Usar autenticação segura e variáveis de ambiente/gestor de segredos; nunca passar palavras-passe em argumentos visíveis nem gravar segredos em logs.
- [ ] Guardar backups fora do repositório e fora do computador principal; cifrar em trânsito e em repouso.
- [ ] Gerar manifesto por execução com data UTC, tipo de backup, versão da aplicação/schema, contagem de ficheiros, tamanhos, checksums SHA-256, resultado e duração; não incluir dados pessoais.
- [ ] Distinguir falha parcial de sucesso total: se Postgres passar mas Storage falhar, o trabalho deve ficar marcado como parcial/falhado e alertar o operador.
- [ ] Aplicar retenção apenas depois de validar a nova cópia; impedir que uma execução incompleta elimine o último backup válido.
- [ ] Critério de aprovação: cópia íntegra, manifesto consistente e falhas simuladas geram estado não-success e não eliminam cópias anteriores.

### Tarefa B3 — Automatização e alertas

**Ficheiros propostos:**
- Criar workflow separado: .github/workflows/nova-toddle-backup.yml, ou usar um agendador/host seguro com acesso controlado.
- Configuração de segredos só no ambiente de execução protegido, nunca em ficheiros versionados.

- [ ] Automatizar após decidir a localização da cópia externa e o gestor de credenciais.
- [ ] Emitir alerta em falha, cópia parcial, checksum divergente ou backup ausente dentro da janela esperada.
- [ ] Limitar permissões do executor ao mínimo necessário; não usar credenciais administrativas gerais se houver alternativa mais restrita.
- [ ] Fazer um teste de perda de rede, credencial inválida, disco cheio e objeto Storage inacessível.
- [ ] Critério de aprovação: execução agendada observável, alertas comprovados e retenção sem perda do último backup válido.

### Tarefa B4 — Restauro de teste e recuperação de desastre

- [ ] Restaurar Postgres num projeto/ambiente isolado, nunca por cima de produção.
- [ ] Restaurar Storage e verificar amostra representativa de ficheiros e respetivos metadados/referências.
- [ ] Executar testes de login, isolamento por instituição, alunos/matrículas, RH, cobranças, documentos fiscais, exportações e NOVA AI.
- [ ] Comparar contagens, relações, checksums e integridade funcional antes/depois do restauro.
- [ ] Medir RPO/RTO observados e documentar diferenças face aos objetivos aprovados.
- [ ] Critério de aprovação: restauro repetível, sem erros críticos, com relatório revisto e procedimento de reversão documentado.

---

## Portas de decisão

1. **Porta de segurança:** não iniciar automatização de backups com credenciais amplas até rever os riscos críticos de RLS/RPC.
2. **Porta de custo:** não ativar serviços pagos ou armazenamento externo pago sem aprovação explícita.
3. **Porta de restauro:** não declarar recuperação pronta antes de um restauro isolado completo.
4. **Porta de produção:** nenhuma alteração de produção, migração, ativação de configuração, publicação ou distribuição sem autorização expressa.

## Decisões ainda necessárias

- RPO/RTO aceitáveis para a escola.
- Retenção além dos 30 dias propostos e orçamento disponível para armazenamento externo.
- Destino da cópia externa e responsável pela gestão das chaves de cifragem.
- Canal de alerta operacional (email, SMS ou outro) e responsável de plantão.
