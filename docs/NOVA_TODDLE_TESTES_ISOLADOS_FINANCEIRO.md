# NOVA TODDLE ESCOLAR — preparação de testes isolados

Data: 2026-10-28  
Estado: preparado para execução num ambiente de desenvolvimento; não executado contra a produção.

## Ambiente encontrado

- Projeto Supabase de NOVA TODDLE ESCOLAR: `rojyxfjaidyvtmsmefcf` (ativo).
- O gestor de branches do Supabase mostra apenas a branch `main` do projeto.
- Não foi encontrada uma branch Supabase de desenvolvimento pronta para executar testes.
- Existe outro projeto Supabase, mas não será usado como ambiente de teste porque pertence a outro contexto e deve permanecer separado.
- Não foi criada uma branch Supabase adicional: a criação pode gerar custos de compute/uso e precisa de confirmação explícita do utilizador.

## Limite de segurança

**Não executar a migração de hardening na produção para “testar”.** A migração altera quatro funções financeiras `SECURITY DEFINER`. Primeiro criar/autorizar ambiente isolado, confirmar que está saudável, aplicar a migração apenas nesse ambiente e validar os resultados.

## Testes obrigatórios (negativos e positivos)

### SEC-FIN-01 — Isolamento multi-instituição
1. Preparar instituição A e instituição B fictícias.
2. Autenticar como utilizador autorizado da instituição A.
3. Tentar emitir documento da instituição A referenciando aluno da instituição B.
4. Esperado: exceção; nenhum documento criado.
5. Repetir com documento de origem da instituição B.
6. Esperado: exceção; nenhum documento criado.

### SEC-FIN-02 — Autoria
1. Autenticar como utilizador A.
2. Chamar emissão passando em `p_criado_por` o UUID de outro utilizador.
3. Esperado: `documentos_fiscais.criado_por = auth.uid()`, nunca o UUID fornecido.

### FIN-03 — Tipo de documento
1. Tentar ligar um recibo a uma cobrança como fatura.
2. Tentar ligar uma fatura como recibo.
3. Esperado: ambas as operações falham e os três campos de ligação permanecem inalterados.
4. Validar separadamente o comportamento de `fatura_recibo), conforme a regra contabilística aprovada.

### FIN-04 — Pagamentos inválidos
Testar valor NULL, zero, negativo, superior ao saldo e método de pagamento de outra instituição.
Esperado: cada chamada inválida falha sem inserir pagamento nem alterar estado da cobrança.

### FIN-05 — Concorrência e repetição
1. Criar cobrança fictícia com saldo controlado.
2. Fazer duas chamadas concorrentes cuja soma exceda o saldo.
3. Esperado: não pode haver saldo pago acima do valor da cobrança.
4. Repetir o mesmo pedido de pagamento após timeout. Avaliar se existe chave de idempotência para impedir duplicação; a função atual não demonstra idempotência por referência.

### FIN-06 — Contabilização
1. Tentar contabilizar documento anulado: deve falhar.
2. Contabilizar documento válido duas vezes: não deve criar lançamentos duplicados.
3. Validar débito = crédito, período contabilístico correto e tipo de nota de crédito/débito.
4. Verificar documentos `fatura_recibo` e notas de débito com casos contabilísticos aprovados por responsável financeiro.

## Verificações técnicas antes de aprovar

- Aplicação da migração concluída sem erros no ambiente isolado.
- Consultar definições das quatro funções e privilégios de execução após a migração.
- Executar advisors de segurança e performance.
- Confirmar que nenhuma instituição vê ou altera dados de outra.
- Testar emissão, ligação fatura/recibo, pagamento, contabilização e geração PDF de ponta a ponta.
- Fazer backup e testar restauração antes de qualquer decisão de produção.

## Critério de saída

A migração permanece **não homologada** até todos os testes passarem num ambiente isolado. Depois disso, rever o diff, o relatório dos advisors e a evidência de backup/restauração antes de solicitar autorização separada para produção.
