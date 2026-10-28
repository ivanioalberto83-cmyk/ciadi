# NOVA TODDLE ESCOLAR — Registo de achados de cibersegurança

**Data do registo:** 2026-10-28  
**Âmbito:** revisão documental e de metadados Supabase/GitHub; sem exploração, sem alterações de produção.  
**Estado geral:** riscos identificados; correções ainda não aprovadas nem aplicadas.  
**Regra de evidência:** “potencial” significa que a configuração observada justifica um teste controlado, não que a exploração tenha sido demonstrada.

## Prioridades

| ID | Prioridade | Achado observado | Risco | Próxima ação segura | Estado |
|---|---|---|---|---|---|
| SEC-01 | Crítica — validar primeiro | A política `staff manage profiles` permite operações `ALL` quando `private.is_tenant_admin()` é verdadeira; a função aparenta incluir funções como `staff`, `reception` e `accountant`. A tabela `perfis` contém o campo `role`; não foi identificado trigger de proteção de alteração de papel no inventário consultado. | Potencial elevação de privilégios ou alteração de perfil alheio, dependendo das expressões completas da política e das demais restrições. | Em homologação, confirmar a definição integral da função/política e testar se utilizador comum consegue alterar o próprio papel ou o de outro utilizador. Corrigir por migração revista, com teste negativo e rollback. | Aberto; não explorado |
| SEC-02 | Alta | Políticas identificadas como `tenant admins manage teachers` e `staff manage student guardians` aparentam não explicitar uma verificação de instituição em todos os caminhos. | Possível acesso ou modificação entre instituições (cross-tenant). | Executar plano com duas instituições fictícias, contas e registos independentes; rever cada política `USING` e `WITH CHECK`. | Aberto; por testar |
| SEC-03 | Alta | Cinco funções `SECURITY DEFINER` com EXECUTE disponível a `authenticated`: `fiscal_emitir_documento`, `nova_atualizar_estado_cobranca`, `nova_criar_cobranca`, `nova_registar_pagamento`, `nova_vincular_documento_cobranca`. | A função pode operar com privilégios elevados se faltar validação de papel, instituição, propriedade, estado ou parâmetros. | Inspecionar código completo, `search_path`, validação do utilizador, idempotência e isolamento por instituição. Não revogar permissões nem alterar funções antes da revisão de impacto. | Aberto; revisão necessária |
| SEC-04 | Alta | A proteção de palavras-passe comprometidas/vazadas no Supabase Auth está desativada. | Maior probabilidade de utilização de palavras-passe conhecidas em incidentes anteriores. | Confirmar disponibilidade no plano/configuração e ativar primeiro em homologação; verificar UX e fluxo de recuperação. | Configuração por alterar; não alterada |
| SEC-05 | Alta | A inscrição pública envia metadados `role: "formando"`, mas o enum `public.user_role` observado não contém `formando`; o trigger encontrado cria registo em `public.formandos`, sem criar registo em `public.perfis`. | Inscrição pode terminar sem acesso normal à aplicação ou criar estado inconsistente. | Definir o modelo de identidade/formando e testar registo, confirmação de email, login, recuperação e desativação em ambiente isolado. | Aberto; por testar |
| SEC-06 | Alta | A função Edge `nova-ai` permite CORS amplo quando `NOVA_AI_ALLOWED_ORIGINS` está ausente, vazia ou configurada com `*`. | Origem web não autorizada pode chamar a função; o impacto depende também da autenticação e validações existentes. | Definir allowlist explícita por ambiente e testar preflight/origens permitidas e negadas. Não colocar segredos no cliente. | Aberto; configuração a validar |
| SEC-07 | Alta — privacidade | A função `nova-ai` envia o nome do aluno no contexto para o fornecedor de IA selecionado. | Tratamento de dados pessoais por terceiro; exposição maior que a necessária se não houver minimização, fundamento, transparência e retenção controlada. | Rever base legal, informação aos encarregados, contratos/termos do fornecedor, retenção e minimização. Testar com dados fictícios. | Revisão de privacidade pendente |
| SEC-08 | Média | Seis tabelas têm RLS ativo mas nenhuma política: `acompanhamentos_rede_educacao`, `contratos_profissionais_nova`, `documentos_candidatura_profissional`, `historico_verificacao_profissional`, `pagamentos_rede_educacao`, `propostas_apoio_educacional`. | Pode ser bloqueio intencional por omissão ou módulo inutilizável; não deve ser “corrigido” sem requisito confirmado. | Confirmar se o comportamento pretendido é deny-all. Criar políticas só após definição de papéis, instituição e fluxo de acesso. | A confirmar com o produto |
| SEC-09 | Média | Foram observadas 120 chaves estrangeiras sem índice de cobertura (alerta de performance). | Operações de join/delete/update podem degradar com crescimento de dados. | Rever uso e volume; propor índices em migração separada, medir plano de consulta e evitar alterações automáticas. | Não prioritário face a acesso |
| SEC-10 | Média | Não foi encontrada no repositório fonte de todas as Edge Functions implantadas. | O código versionado pode não representar o código em execução; auditoria de exportação, PDF e SAF-T fica incompleta. | Exportar/recuperar fonte implantada de forma autorizada, comparar com Git e registar hash/versão antes de auditar. | Pendente |
| SEC-11 | Média | As políticas CORS, a configuração de Auth e as funções privilegiadas ainda não têm evidência de testes negativos documentada neste ramo. | Regressões ou permissões excessivas podem passar despercebidas. | Adicionar casos de teste de autorização e executar apenas em homologação. | Pendente |

## Critérios mínimos de encerramento

- [ ] SEC-01: conta de baixo privilégio não consegue alterar papel nem perfil de outro utilizador.
- [ ] SEC-02: utilizador da Instituição A não lê, cria, altera nem apaga dados da Instituição B por API ou função.
- [ ] SEC-03: cada função privilegiada valida identidade, papel, instituição, propriedade e estado; `search_path` está controlado.
- [ ] SEC-04: proteção de palavras-passe comprometidas testada em homologação.
- [ ] SEC-05: ciclo de inscrição e autenticação completo validado.
- [ ] SEC-06: CORS permite apenas origens previstas.
- [ ] SEC-07: minimização e tratamento de dados por IA documentados e aprovados.
- [ ] SEC-08: decisão funcional documentada para cada tabela sem política.
- [ ] SEC-10: fonte implantada comparada com fonte versionada.

## Limites e proteção operacional

Este documento não comprova exploração de vulnerabilidades nem certifica conformidade legal. Não executar alterações SQL, políticas RLS, Auth, funções ou Edge Functions em produção sem autorização explícita, backup verificado e plano de reversão. Usar exclusivamente dados e contas fictícios nos testes.
