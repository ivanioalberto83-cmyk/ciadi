# Auditoria inicial — NOVA TODDLE ESCOLAR
Data: 2026-10-28
Repositório: ivanioalberto83-cmyk/ciadi
Branch de trabalho: feat/nova-toddle-finance-rh-agt-20261028
Supabase: rojyxfjaidyvtmsmefcf

## Âmbito e segurança
A análise foi feita em modo de leitura no Supabase. Não foram aplicadas migrações, alterações de tabelas, políticas RLS ou dados de produção.

## Estado funcional observado
- A base de dados tem tabelas de faturação, séries fiscais, linhas de documentos, pagamentos, exportações SAF-T, submissões AGT, plano de contas, lançamentos e períodos contabilísticos.
- O menu Financeiro não tinha um ecrã especializado associado; o RH e Compras usavam um formulário CRUD genérico.
- O RH atual tem cadastro, férias e documentos, mas não há tabelas de folha salarial nem regras IRT/INSS versionadas na base de dados.
- Compras tem fornecedores e cabeçalho de pedidos, mas não existe tabela de linhas de pedido/receção identificada no esquema atual; o fluxo completo de aprovisionamento precisa de migração própria.
- A função fiscal existente `fiscal_emitir_documento` emite no sistema e gera hash, mas isso não demonstra por si só submissão ou aceitação pela AGT.
- **Bloqueio crítico:** a proteção de emissão implementada nesta branch é apenas da interface. A RPC existente continua disponível na base de dados para os papéis autorizados e ainda não verifica no servidor uma tabela de regras fiscais oficiais validadas nem o estado de autorização AGT da série. Portanto, não deve ser usada para emissão de produção até existir uma migração de endurecimento server-side testada.
- Existe a função `contabilizar_documento_fiscal`, que cria lançamentos e verifica o equilíbrio, dependendo da configuração contabilística da instituição.
- A consulta de configuração encontrou uma série fiscal de tipo `fatura` em estado `homologacao`, sem código AGT e com quantidade autorizada igual a zero. Por isso, o ecrã bloqueia a emissão em vez de assumir que a série está autorizada.
- O teste do instalador falhava por uma expressão regular mal escapada em `tests/build-smoke.test.js`, impedindo a execução dos testes seguintes.

## Alertas dos Supabase Advisors observados
- 5 funções financeiras `SECURITY DEFINER` podem ser chamadas por utilizadores autenticados; rever privilégios e autorização por instituição antes de produção.
- 6 tabelas com RLS ativo sem políticas: inclui `contratos_profissionais_nova`, `documentos_candidatura_profissional`, `historico_verificacao_profissional` e outras.
- 54 ocorrências de políticas permissivas duplicadas/sobrepostas.
- 120 chaves estrangeiras sem índice de cobertura.
- 9 políticas com chamadas de autenticação que podem ser otimizadas.
- 198 índices sem uso observado e 2 pares de índices duplicados.
- A proteção de palavra-passe comprometida está desativada.

Os alertas de desempenho devem ser priorizados com evidência de uso; não remover índices nem alterar políticas automaticamente, pois isso pode quebrar operações ou isolamento multi-escola.

## Alterações propostas nesta branch
- Adicionado motor JavaScript de cálculo de linhas, validação de séries fiscais, cálculo salarial parametrizado, validação de lançamentos e cálculo de pedidos.
- Adicionados ecrãs especializados de Faturação, Contabilidade, RH e Compras.
- A emissão fiscal é bloqueada pela interface quando a série não apresenta código, estado de autorização e quantidade autorizada compatíveis. O estado da série deve ser confirmado oficialmente.
- O motor salarial não incorpora taxas legais inventadas: exige fonte, data de vigência, taxas INSS e escalões IRT configurados.
- A interface de Compras assinala explicitamente que o esquema atual ainda não suporta linhas/receções de pedido.
- Corrigido o teste smoke e adicionada cobertura dos motores de cálculo.

## Pendências para homologação
1. Validar os valores de estado/código/quantidade das séries fiscais com a AGT e o responsável contabilístico.
2. Rever a autorização e os privilégios das funções financeiras `SECURITY DEFINER`; não fazer alterações em produção sem testes e aprovação.
3. Criar e testar migração para regras salariais versionadas, folhas salariais, recibos e linhas/receções de aprovisionamento, com RLS por instituição.
4. Testar documentos fiscais e lançamentos com dados fictícios em ambiente isolado.
5. Validar o XML SAF-T contra XSD e requisitos oficiais aplicáveis antes de declarar conformidade.
6. Gerar o Setup.exe apenas após CI verde; a compilação anterior falhou no teste smoke, antes de produzir o instalador.

**Conclusão:** existem bases de dados e algumas RPCs úteis, mas o sistema ainda não deve ser declarado homologado pela AGT nem pronto para emissão fiscal oficial.
