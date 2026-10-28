# NOVA TODDLE ESCOLAR — plano de auditoria e homologação

Estado: auditoria em curso. Este documento é um registo de trabalho; não certifica conformidade nem aprovação para produção.

## Regras de segurança
- Não executar DDL/DML, migrações, alterações de RLS ou revogações em produção durante a auditoria.
- Não publicar nem distribuir instaladores sem autorização explícita.
- Usar apenas contas, instituições, alunos, profissionais, documentos e pagamentos fictícios num ambiente de teste isolado.
- Não colocar chaves secretas, tokens, palavras-passe ou dados pessoais neste repositório.

## Achado de segurança prioritário — isolamento entre instituições

A leitura das políticas RLS e funções auxiliares no Supabase revelou uma combinação que deve ser tratada como crítica e validada em ambiente isolado antes de qualquer correção:

- `private.is_tenant_admin()` devolve verdadeiro para os papéis `school_admin`, `principal`, `academic_director`, `accountant`, `reception` e `staff`.
- Várias políticas de gestão utilizam essa função como condição administrativa, incluindo políticas para alunos e instituição.
- A política `tenant admins manage teachers` da tabela `professores` utiliza `private.is_super_admin() OR private.is_tenant_admin()` sem uma condição explícita que limite a linha à instituição atual.

Isto pode permitir que perfis não administrativos obtenham permissões de gestão demasiado amplas e, na política de professores, potencialmente entre instituições. É um achado baseado na lógica SQL; não foi executado teste de exploração nem alterada qualquer política.

**Ação bloqueante:** desenhar uma matriz explícita de papéis (super_admin global; administrador da escola; direção; professor; receção; contabilista; funcionário; encarregado/formando), rever todas as políticas que chamam `is_tenant_admin()` e testar acessos cruzados com duas instituições fictícias. Não corrigir simplesmente a função auxiliar sem rever os seus consumidores, pois isso pode bloquear fluxos legítimos ou deixar outras permissões inconsistentes.

### Subachado crítico — alteração de papéis em `perfis`

A política RLS `staff manage profiles` permite `ALL` a quem satisfaça `private.is_tenant_admin()`, com condição de linha centrada na instituição. A tabela `perfis` inclui a coluna `role`, e a inspeção não encontrou triggers na tabela que protejam alterações de papel. Como `is_tenant_admin()` inclui também `staff`, `reception` e `accountant`, a combinação cria um risco sério de um utilizador autorizado a editar perfis alterar o próprio papel para `super_admin`, se a política se aplicar como lida.

**Classificação preliminar: crítico, requer validação imediata.** Não foi feita tentativa de exploração nem alteração na base de dados. A correção deve separar permissões de edição de dados de perfil das alterações de papel, impedir que o próprio utilizador altere `role`/`instituicao_id`, e reservar atribuição de papéis a um fluxo administrativo seguro que valide explicitamente a instituição e os papéis permitidos.

### Subachado crítico — relações encarregado/aluno

A política `staff manage student guardians` na tabela `aluno_encarregado` permite `ALL` a `is_tenant_admin()` sem condição explícita de instituição na linha. É necessário confirmar a estrutura da tabela e as relações associadas para garantir que um perfil escolar não consegue alterar ligações de alunos de outra instituição. Não foram executados testes de exploração nem alteradas políticas.

## Fase 1 — Autenticação e isolamento
- [x] Adicionar pedido de recuperação de palavra-passe no login, com resposta genérica para reduzir enumeração de contas e retorno limitado à origem/caminho atuais; [ ] confirmar allowlist de Redirect URLs no Supabase e testar entrega do email.
- [ ] Confirmar a atribuição segura de perfis; impedir autoelevação para super_admin.
- [ ] **Bloqueante/crítico:** rever `staff manage profiles`: a política `ALL` permite gerir a coluna `role`, sem trigger de proteção observada; validar risco de autoelevação para `super_admin`.
- [ ] **Bloqueante/crítico:** rever `tenant admins manage teachers` e `staff manage student guardians`, que não impõem explicitamente a instituição na condição da linha.
- [ ] Testar isolamento entre duas instituições com contas de papéis distintos.
- [ ] Rever as funções SECURITY DEFINER e o EXECUTE concedido a authenticated; só ajustar após verificar os consumidores e a matriz de permissões. Achado para revisão: `fiscal_emitir_documento` aceita `p_criado_por` como argumento e grava esse valor; confirmar se pode permitir falsificação de autoria antes de propor correção.
- [ ] Rever tabelas com RLS ativo sem políticas e definir se o bloqueio é intencional ou se faltam políticas.
- [ ] Ativar proteção contra palavras-passe comprometidas após validar impacto e configuração de Auth.

## Fase 2 — Gestão escolar e RH
- [ ] Testar aluno, encarregado, matrícula, turma, presença e avaliação em dados fictícios.
- [ ] Verificar integridade referencial e instituição em todas as operações.
- [ ] Testar criação de colaborador, contrato, candidatura e documentos privados.
- [ ] Confirmar separação entre permissões de leitura, escrita e gestão.

## Fase 3 — Faturação, contabilidade e SAF-T
- [ ] Testar série e numeração, cliente, linhas, impostos, totais, pagamento, recibo e saldo.
- [ ] Testar repetição de pedidos e prevenir pagamentos/lançamentos duplicados.
- [ ] Confirmar período contabilístico, partidas equilibradas e ligações a documentos de origem.
- [ ] Validar o SAF-T com ficheiros de teste e regras fiscais aplicáveis; não inferir conformidade apenas da geração do XML.

## Fase 4 — Exportações, IA e SOS
- [ ] Comparar PDF, XLSX e CSV com os registos de origem, incluindo paginação, acentos, totais e datas.
- [ ] Testar permissões, minimização de dados e isolamento institucional na IA; configurar `NOVA_AI_ALLOWED_ORIGINS` explicitamente e rever o envio de nomes de alunos ao fornecedor externo.
- [ ] Testar denúncia anónima, controlo de acesso e entrega efetiva de notificações SOS.
- [ ] Verificar que dados de saúde, alunos e RH não são expostos por URLs ou logs.

## Fase 5 — Windows e homologação
- [ ] Executar testes unitários e estáticos em CI.
- [ ] Validar instalação limpa, atualização, persistência, sessão e falha de rede numa máquina de teste.
- [ ] Gerar o instalador como artefacto de CI, inspecionar assinatura/hash e testar sem publicar.
- [ ] Só distribuir após revisão do relatório e autorização expressa.

## Evidência disponível nesta revisão
- O código foi atualizado apenas na branch isolada para adicionar o pedido de recuperação; nenhuma alteração foi aplicada ao Supabase.
- 21 verificações estáticas executadas sobre os ficheiros da branch passaram localmente via inspeção automatizada; a execução completa do workflow Windows ainda está pendente.
- A aplicação Electron declara contextIsolation, nodeIntegration desativado e sandbox ativo.
- A inicialização web carrega Supabase JS de dois CDNs e apresenta erro se ambos falharem; isto continua dependente de rede.
- O teste smoke original usava uma expressão regular frágil que não refletia a estrutura real do timeout.
- Funções de cobrança e emissão fiscal têm EXECUTE concedido a authenticated; a autorização interna de cada função necessita de revisão.
- A auditoria de código não substitui testes de ponta a ponta nem validação fiscal independente.

## Achado funcional de autenticação — registo público de formandos

O formulário público chama `auth.signUp` e envia metadados com `role: "formando"`. A enumeração SQL de `public.user_role` não contém o valor `formando`; contém, entre outros, `student`. A única trigger encontrada em `auth.users` é `private.ensure_formando_from_auth()`, que cria um registo em `public.formandos`, mas não cria um registo em `public.perfis`. Por sua vez, a função `load()` da aplicação exige um registo ativo em `perfis` e devolve "Perfil não encontrado" se não existir.

Conclusão: o fluxo de auto-registo público parece não criar o perfil exigido pelo login geral. Não foi feito um registo de teste real porque o ambiente não está isolado. Antes de corrigir, é necessário definir o modelo de identidade dos formandos (por exemplo, um perfil `student` com acesso apenas ao LMS, ou uma área de autenticação separada) e testar o ciclo criar conta → confirmar email → entrar → consultar cursos, sem permitir que metadados do utilizador atribuam papéis privilegiados.

## Achados adicionais de IA e privacidade

- A Edge Function `nova-ai` valida o Bearer token, verifica o perfil ativo e confirma que o aluno selecionado pertence à instituição do perfil. Estes são controlos positivos observados no código.
- Quando um aluno é selecionado, o nome do aluno é incluído no contexto enviado ao fornecedor externo de IA. Confirmar base legal, transparência/consentimento, retenção e minimização de dados antes de uso com alunos reais.
- O CORS da função permite origens de qualquer domínio quando `NOVA_AI_ALLOWED_ORIGINS` está ausente/vazio ou contém `*`. A função exige autenticação, mas a lista de origens deve ser configurada explicitamente para os domínios aprovados e testada.
- Não foi possível auditar o conteúdo real das outras Edge Functions a partir dos ficheiros versionados; ver a secção de rastreabilidade abaixo.

## Verificação de integridade dos dados (consultas só de leitura)

Consulta agregada às tabelas principais:
- Alunos: 1 registo.
- Matrículas, presenças, resultados, cobranças escolares, pagamentos escolares, documentos fiscais, linhas fiscais, RH, denúncias SOS e conversas/mensagens de IA: 0 registos nas tabelas consultadas.
- As verificações de órfãos para matrículas, presenças, resultados, pagamentos, linhas fiscais e cobranças não encontraram ocorrências.
- Não foram encontradas divergências entre a instituição da cobrança e a do aluno, nem entre a instituição do aluno e a da turma nas matrículas.

Interpretação: estas verificações de integridade passaram para os dados atualmente existentes, mas a base de dados quase vazia não permite validar fluxos reais de ponta a ponta. A homologação funcional exige um ambiente de teste com dados fictícios e cenários completos; não inserir dados de teste na produção.

## Rastreabilidade do código de backend

A árvore da branch principal contém o código-fonte versionado da função `nova-ai`, mas não contém fontes equivalentes para todas as Edge Functions identificadas no projeto Supabase. Os geradores PDF, exportações e SAF-T não devem ser considerados auditados até que a fonte exata implantada esteja recuperada e comparada com a versão versionada. Esta divergência reduz a reprodutibilidade e aumenta o risco de alterações não rastreadas.

## Proposta fiscal de revisão

Foi colocado em `audit/proposed-migrations/20261028_hardening_fiscal_emitir_documento.sql` um rascunho de reforço para validar a instituição do aluno e do documento de origem, e fixar a autoria no utilizador autenticado. Está fora de `supabase/migrations` intencionalmente para evitar execução automática. Não foi aplicado nem validado pelo motor PostgreSQL; exige revisão e testes numa cópia isolada antes de qualquer adoção.

## Critério de saída
Cada item só pode ser marcado como concluído quando houver evidência reproduzível, resultado do teste e revisão. Nenhuma alteração de produção ou publicação está autorizada por este documento.


## Fase 6 — Cibersegurança (adicionada em 28-10-2026)

A leitura dos advisors de segurança do Supabase identificou:
- 6 tabelas com RLS ativo sem políticas: acompanhamentos_rede_educacao, contratos_profissionais_nova, documentos_candidatura_profissional, historico_verificacao_profissional, pagamentos_rede_educacao e propostas_apoio_educacional. Isto pode ser intencional como bloqueio total; confirmar o comportamento pretendido antes de qualquer alteração.
- 5 funções SECURITY DEFINER executáveis por authenticated foram sinalizadas: fiscal_emitir_documento, nova_atualizar_estado_cobranca, nova_criar_cobranca, nova_registar_pagamento e nova_vincular_documento_cobranca. Rever autorização interna, search_path, validação de instituição, idempotência e privilégio mínimo antes de decidir revogar EXECUTE ou mudar o modo de segurança.
- Proteção de Auth contra palavras-passe comprometidas está desativada.
- Mantêm-se os riscos críticos já registados de isolamento entre instituições e de gestão de papéis/perfis.

**Estado:** observações obtidas em modo de leitura. Nenhuma política, função, configuração de Auth ou segredo foi alterado. As tabelas sem políticas não devem receber políticas automaticamente sem uma matriz de permissões e testes. O relatório de findings e a validação em ambiente isolado são bloqueantes.

## Fase 7 — Backups e recuperação de desastre (planeada; ainda não implementada)

Foi criado um plano separado em `docs/plans/2026-10-28-ciberseguranca-backups-nova-toddle.md`. Inclui inventário Postgres/Storage, cópia externa cifrada, manifesto SHA-256, alertas de falha, retenção segura e restauro em ambiente isolado.

**Limitações atuais:** não foi executado backup novo, não foi testado restauro, e não foi alterada qualquer configuração de produção. O backup de Postgres não deve ser tratado como cópia dos objetos Storage. A frequência diária e retenção inicial de 30 dias são propostas para aprovação, não configurações ativas. RPO/RTO, destino externo, custo e gestão de chaves permanecem por decidir.



## Revisão adicional — segurança do procedimento de restauro

A inspeção estática de `scripts/backup/restore-nova-toddle.ps1` identificou um bloqueio adicional antes de qualquer teste real: a URI completa de ligação (`$databaseUrl`) é passada como argumento de linha de comando a `pg_restore`/`psql`. Se a URI incluir credenciais, estas podem ficar expostas na lista de processos ou em ferramentas de diagnóstico do sistema.

- [ ] **Bloqueante:** retirar o segredo dos argumentos do processo antes de usar o script em homologação. Preferir um mecanismo de credenciais suportado pelo PostgreSQL e adequado ao sistema operativo (por exemplo, ficheiro `pgpass` temporário com permissões restritas), com limpeza garantida em bloco `finally`; não registar URI, utilizador ou palavra-passe.
- [ ] Validar a interpretação de URI/hostname e a allowlist com casos negativos, incluindo hosts semelhantes ao host autorizado, URI malformada e destino de produção.
- [ ] Rever opções destrutivas (`--clean --if-exists`) e exigir uma base de homologação descartável, previamente identificada e sem integrações reais.
- [ ] Confirmar o hash por manifesto independente e verificar a origem, integridade e proteção do backup antes de restaurar.
- [ ] Testar a restauração em ambiente isolado e validar schema, extensões, funções, triggers, grants, RLS, contagens e Storage.

O script atual é um protótipo com salvaguardas, **não está aprovado para execução real**. Não foi executado qualquer restauro nem alterada a produção nesta revisão.
