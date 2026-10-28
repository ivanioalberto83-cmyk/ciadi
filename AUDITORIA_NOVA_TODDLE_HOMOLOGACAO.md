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

## Fase 1 — Autenticação e isolamento
- [x] Adicionar pedido de recuperação de palavra-passe no login, com resposta genérica para reduzir enumeração de contas e retorno limitado à origem/caminho atuais; [ ] confirmar allowlist de Redirect URLs no Supabase e testar entrega do email.
- [ ] Confirmar a atribuição segura de perfis; impedir autoelevação para super_admin.
- [ ] **Bloqueante:** rever o uso demasiado amplo de `private.is_tenant_admin()` e a política `tenant admins manage teachers`, que não limita explicitamente o acesso à instituição atual.
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
- [ ] Testar permissões, minimização de dados e isolamento institucional na IA.
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
