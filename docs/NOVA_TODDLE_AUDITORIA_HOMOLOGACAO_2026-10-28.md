# NOVA TODDLE ESCOLAR — Relatório de auditoria para homologação
**Data:** 2026-10-28  
**Branch:** `nova-toddle-escolar`  
**Repositório:** `ivanioalberto83-cmyk/ciadi`  
**Supabase:** `rojyxfjaidyvtmsmefcf`  
**Tipo de verificação:** leitura apenas; nenhuma alteração de dados, esquema, políticas ou funções foi aplicada.

## Resumo executivo
**Estado: NÃO HOMOLOGADO — validação técnica em curso.** O projeto Supabase está ativo, mas os avisos de segurança e os testes funcionais ponta a ponta impedem uma declaração de prontidão.

## Integridade dos ficheiros
- `index.html`: presente na branch; blob SHA `a31dc8610b6dfd72d8c8c13d86ecd2e38615730c`; 78.698 caracteres devolvidos pelo conector.
- `index_nova_toddle_school_pro_AGT_READY.html`: presente na branch; blob SHA `784410896144493ea9f9330981e84e32db093b03`; 134.142 caracteres devolvidos pelo conector.
- Os ficheiros são diferentes. Ambos devem ser preservados durante a correção.

## Findings de segurança do Supabase
1. **6 tabelas com RLS ativado e sem políticas** (aviso do Supabase Advisor):
   - `public.acompanhamentos_rede_educacao`
   - `public.contratos_profissionais_nova`
   - `public.documentos_candidatura_profissional`
   - `public.historico_verificacao_profissional`
   - `public.pagamentos_rede_educacao`
   - `public.propostas_apoio_educacional`
   
   A ausência de políticas pode bloquear acessos legítimos; não se deve resolver adicionando permissões genéricas. É necessário determinar o modelo de acesso de cada tabela e confirmar os grants.

2. **Funções SECURITY DEFINER acessíveis a utilizadores autenticados** foram sinalizadas pelo Advisor. Entre as funções confirmadas na consulta de privilégios estão:
   - `public.fiscal_emitir_documento(...)`: `authenticated` tem EXECUTE; a função verifica perfil, instituição, tipo e série, mas requer revisão de autorização e integridade do processo.
   - `public.nova_atualizar_estado_cobranca(uuid)`: `authenticated` tem EXECUTE; contém verificação de autenticação, papel e instituição; rever exposição e idempotência.
   - `public.nova_criar_cobranca(...)`: `authenticated` tem EXECUTE; contém verificação de autenticação e instituição; rever validação de autorização e consistência.
   - `public.contabilizar_documento_fiscal(uuid)`: a consulta confirmou `SECURITY DEFINER`, com EXECUTE não concedido diretamente a `anon` nem a `authenticated` na verificação atual.
   
   A decisão de manter SECURITY DEFINER, mudar para SECURITY INVOKER ou restringir EXECUTE deve ser tomada função a função, após revisão do código completo e dos fluxos dependentes. Não aplicar revogações em produção sem testes e plano de reversão.

3. **120 chaves estrangeiras sem índice de cobertura** foram reportadas pelo Advisor de desempenho. É necessário gerar inventário completo, verificar índices existentes e medir impacto antes de criar índices.

4. **Políticas permissivas sobrepostas** existem em diversas tabelas, incluindo cobrança e pagamentos escolares. Políticas permissivas podem combinar-se com lógica OR; analisar cada conjunto de políticas, sem eliminar regras até comprovar a intenção de acesso.

5. As views `v_cobrancas_escolares` e `v_relatorio_pagamentos_escolares` têm a opção `security_invoker=true` confirmada na consulta atual.

## Bloqueadores funcionais já registados
- **SAF-T — divergência confirmada e corrigida na branch:** a interface apresentava `F/I/C`, enquanto a Edge Function `saft-gerar` aceita `F/I/R`. Foi alterado o valor da opção contabilística de `C` para `R` apenas no ficheiro `index_nova_toddle_school_pro_AGT_READY.html`. A correção foi verificada no GitHub. Ainda falta testar a função autenticada; não foi publicada nem se afirma conformidade oficial.
- **PDF fiscal — erro de coluna confirmado e corrigido na branch:** a função `gerar-documento-pdf` consultava `documentos_fiscais_linhas.documento_fiscal_id`, mas o esquema real usa `documento_id`. A versão corrigida foi adicionada a `supabase/functions/gerar-documento-pdf/index.ts` e verificada no GitHub. **A função ativa no Supabase não foi redeployada** e permanece por corrigir em produção até existir autorização e plano de testes. A interface atual também não invoca ainda esta função; a integração ponta a ponta do PDF continua pendente.
- Ciclo financeiro ainda carece de teste autenticado ponta a ponta: aluno → cobrança → pagamento → documento fiscal → contabilização → SAF-T → fecho.
- RH e Aprovisionamento precisam de validação funcional real (criar, guardar, consultar, editar e autorizar) com perfis apropriados.
- Isolamento multiempresa deve ser testado com duas instituições de teste e utilizadores de cada instituição, comprovando que uma instituição não lê nem altera dados da outra.
- Backup e restauração: a restauração ainda não está comprovada por teste documentado.

## Segunda ronda — revisão das funções financeiras (leitura apenas, 2026-10-28)

### Confirmações adicionais
- As seis tabelas sem políticas têm efetivamente `relrowsecurity=true` e zero entradas em `pg_policies`. O efeito exato depende também dos GRANTs; não se deve assumir que estão expostas. É preciso verificar os GRANTs e o uso esperado antes de adicionar políticas.
- `public.fiscal_emitir_documento(...)` aceita EXECUTE por `authenticated` e usa `SECURITY DEFINER`. A função verifica o papel e a instituição declarada, mas a revisão identificou que `p_criado_por` é recebido do cliente e gravado no documento sem exigir igualdade a `auth.uid()`; também não foi encontrada validação explícita de que `p_aluno_id`, quando fornecido, pertence à instituição. Requer correção/testes antes de produção.
- `public.nova_vincular_documento_cobranca(...)` é executável por `authenticated` e usa `SECURITY DEFINER`. Confirma a mesma instituição e o papel, mas não confirma explicitamente que o tipo real do documento fiscal corresponde a `p_tipo` (fatura/recibo). Requer validação do tipo e testes de associação indevida.
- `public.nova_registar_pagamento(...)` verifica o papel/instituição, valor positivo e impede que a soma ultrapasse o total. Ainda falta teste concorrente de pagamentos simultâneos, idempotência/repetição e ligação correta ao documento fiscal/recibo.
- `public.contabilizar_documento_fiscal(uuid)` não tem EXECUTE direto concedido a `anon` ou `authenticated` na verificação atual. Contudo, a lógica permite estado `anulado` na validação de elegibilidade e depois pode gerar lançamento para um documento anulado; a regra deve ser revista e testada. A consulta não demonstrou que exista atualmente um caminho exposto para invocação por utilizadores normais.
- As políticas de `cobrancas_escolares` e `pagamentos_escolares` contêm políticas permissivas sobrepostas. Como políticas permissivas se combinam por OR, validar a matriz de papéis é essencial para evitar que uma política mais ampla neutralize a intenção de outra.

### Prioridade sugerida
1. **Crítica antes de produção:** validar `p_criado_por`, pertença de aluno à instituição e tipo de documento na ligação cobrança/documento.
2. **Alta:** validar contabilização de documentos anulados, pagamentos concorrentes/repetidos e privilégios de todas as funções SECURITY DEFINER.
3. **Alta:** documentar os GRANTs e a intenção de acesso nas seis tabelas RLS sem políticas.
4. **Média:** analisar políticas permissivas sobrepostas e inventário das 120 FKs sem índice, medindo desempenho antes de alterações.

Nenhuma função SQL, política RLS, GRANT, dado ou Edge Function ativa foi alterada nesta segunda ronda. As correções são propostas até existir ambiente de homologação isolado, testes e aprovação de publicação.

## Plano de trabalho seguro
1. Manter esta fase em leitura apenas; não alterar produção nem RLS.
2. Recolher a definição integral das funções sinalizadas, todas as políticas das tabelas afetadas e os grants relevantes.
3. Rever o fluxo de autorização multiempresa, incluindo funções SECURITY DEFINER, e desenhar testes negativos e positivos.
4. Confirmar os contratos de dados do SAF-T e PDF nos dois HTML e nas funções SQL.
5. Preparar correções numa branch de homologação separada ou numa proposta de alterações revisável; não aplicar diretamente na base de dados de produção.
6. Executar testes funcionais, isolamento entre instituições, segurança, exportação fiscal, PDF, backups e restauração; guardar evidências.
7. Só considerar homologação técnica após todos os testes críticos passarem. Qualquer certificação/homologação oficial AGT exige evidência formal aplicável; este relatório não afirma certificação.

## Limites desta auditoria
Este relatório documenta os resultados de consultas de leitura e avisos do Advisor observados em 2026-10-28. Não foi realizado teste de penetração, não foram feitas alterações à base de dados e não existe evidência nesta fase de homologação oficial AGT.
