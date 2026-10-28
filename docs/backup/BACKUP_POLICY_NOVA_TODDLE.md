# NOVA TODDLE ESCOLAR — Política proposta de backups

**Estado:** proposta para aprovação; não está ativa nem automatizada.  
**Âmbito:** PostgreSQL/Supabase, Storage (objetos), configuração essencial e código versionado.  
**Regra:** backups de produção só podem ser ativados após definição de destino, credenciais, custo, retenção e aprovação explícita.

## Objetivos de recuperação a decidir

| Item | Proposta inicial | Aprovação necessária |
|---|---|---|
| Frequência PostgreSQL | Diária; considerar backup adicional antes de migração/alteração importante | Confirmar RPO e capacidade de exportação |
| Frequência Storage | Diária, ou alinhada com alterações de ficheiros; verificar separadamente dos dados SQL | Confirmar volume e método de exportação |
| Retenção | 30 dias como hipótese inicial | Confirmar obrigação operacional/legal e espaço |
| Cópia externa | Uma cópia cifrada fora do ambiente principal | Escolher destino e custo; nenhum fornecedor contratado |
| Integridade | SHA-256 por ficheiro e manifesto sem dados pessoais | Obrigatório |
| Alertas | Falha de backup/verificação deve gerar alerta para responsável | Definir canal e responsável |
| Restauro | Teste isolado antes de declarar backup recuperável; periodicidade proposta trimestral e após mudanças críticas | Aprovar calendário |

Não declarar RPO/RTO como garantidos até medir duração do backup/restauro e validar capacidade de recuperação. O valor de 30 dias é uma proposta, não uma política já implementada.

## Componentes que têm de ser cobertos

1. **PostgreSQL:** esquema e dados; incluir validação de integridade do ficheiro exportado. Confirmar método compatível com a versão Supabase/Postgres.
2. **Supabase Storage:** objetos binários e metadados necessários. Backup SQL não implica cópia dos ficheiros armazenados.
3. **Configuração:** lista controlada de URLs/redirects, nomes de funções, configuração não secreta e instruções de implantação. Nunca exportar segredos para o repositório.
4. **Código:** commit/tag e versão exata do código correspondente ao backup.
5. **Manifesto:** timestamp UTC, ambiente, commit, tamanho, SHA-256, resultado da validação e identificador não sensível do backup. Não incluir NIF, dados de alunos, nomes, tokens ou URLs assinadas.

## Segurança dos backups

- Cifrar em trânsito e em repouso; gerir a chave separadamente do backup.
- Aplicar menor privilégio às credenciais; usar conta exclusiva para backup e acesso limitado ao destino.
- Não guardar `service_role`, senha de banco, token, chave de cifragem ou credenciais no Git, manifestos ou logs.
- Não colocar dados de produção em artefactos públicos do GitHub Actions.
- Restringir quem pode ler, eliminar ou restaurar cópias; registar operações.
- Definir proteção contra eliminação acidental ou maliciosa e verificar se o destino suporta retenção imutável.
- Remover temporários de forma segura e não deixar ficheiros desprotegidos em computadores partilhados.
- Antes de expirar/eliminar backups, confirmar retenção aprovada e eventuais obrigações legais.

## Procedimento de cada execução

1. Identificar ambiente e versão; validar que não se trata de uma ação de restauro.
2. Obter exportação da base de dados por método aprovado.
3. Exportar objetos do Storage separadamente e confirmar contagens/tamanhos.
4. Cifrar os artefactos antes de os copiar para o destino externo.
5. Calcular SHA-256 e gerar manifesto sem dados pessoais.
6. Recalcular hash após transferência e comparar.
7. Registar sucesso/falha, duração e volume; alertar em falha.
8. Não marcar como “recuperável” até um restauro isolado bem-sucedido.

## Portas de aprovação antes da automação

- [ ] RPO/RTO definidos e aprovados.
- [ ] Destino externo, região, titularidade e custo aprovados.
- [ ] Cifração e gestão de chaves documentadas.
- [ ] Credenciais de menor privilégio criadas fora do repositório.
- [ ] Backup PostgreSQL testado e validado.
- [ ] Storage validado de forma independente.
- [ ] Restauro isolado testado e evidência guardada.
- [ ] Alertas, retenção e responsáveis definidos.
- [ ] Revisão de privacidade/transferência internacional quando aplicável.
- [ ] Aprovação explícita para produção.

## Limitações atuais

Nenhum script de backup, workflow automático, cópia externa ou restauro é declarado implementado por este documento. Não foram validados custos nem executado backup de produção. A existência de exportações antigas não substitui um teste de restauro.
