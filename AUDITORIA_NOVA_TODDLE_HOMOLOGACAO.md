# NOVA TODDLE ESCOLAR — plano de auditoria e homologação

Estado: auditoria em curso. Este documento é um registo de trabalho; não certifica conformidade nem aprovação para produção.

## Regras de segurança
- Não executar DDL/DML, migrações, alterações de RLS ou revogações em produção durante a auditoria.
- Não publicar nem distribuir instaladores sem autorização explícita.
- Usar apenas contas, instituições, alunos, profissionais, documentos e pagamentos fictícios num ambiente de teste isolado.
- Não colocar chaves secretas, tokens, palavras-passe ou dados pessoais neste repositório.

## Fase 1 — Autenticação e isolamento
- [ ] Implementar e testar recuperação de palavra-passe, incluindo destino de retorno permitido.
- [ ] Confirmar a atribuição segura de perfis; impedir autoelevação para super_admin.
- [ ] Testar isolamento entre duas instituições com contas de papéis distintos.
- [ ] Rever as funções SECURITY DEFINER e o EXECUTE concedido a authenticated; só ajustar após verificar os consumidores e a matriz de permissões.
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
- A aplicação Electron declara contextIsolation, nodeIntegration desativado e sandbox ativo.
- A inicialização web carrega Supabase JS de dois CDNs e apresenta erro se ambos falharem; isto continua dependente de rede.
- O teste smoke original usava uma expressão regular frágil que não refletia a estrutura real do timeout.
- Funções de cobrança e emissão fiscal têm EXECUTE concedido a authenticated; a autorização interna de cada função necessita de revisão.
- A auditoria de código não substitui testes de ponta a ponta nem validação fiscal independente.

## Critério de saída
Cada item só pode ser marcado como concluído quando houver evidência reproduzível, resultado do teste e revisão. Nenhuma alteração de produção ou publicação está autorizada por este documento.
