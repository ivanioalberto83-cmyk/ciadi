# NOVA TODDLE ESCOLAR — Plano de restauração automática com salvaguardas

**Estado:** desenho de implementação na branch de auditoria; ainda não ativo.  
**Destino escolhido:** backups associados ao Supabase.  
**Modo escolhido:** deteção de falhas e início de recuperação com salvaguardas adicionais.  
**Limite de segurança:** recuperação automática apenas em homologação. Produção exige aprovação humana explícita.

## Princípio de desenho

“Backups associados ao Supabase” não significa que um dump da base de dados inclua automaticamente os objetos do Supabase Storage, configuração de Auth, segredos, funções Edge ou configurações do projeto. Cada componente precisa de cópia e validação próprias. A restauração deve usar um projeto de homologação dedicado, nunca o projeto de produção por inferência.

## Fluxo proposto

1. **Agendamento:** um workflow de backup gera exportações de PostgreSQL e Storage em passos separados. O método de exportação deve ser validado para a versão do Supabase/PostgreSQL utilizada.
2. **Armazenamento:** guardar as cópias num destino privado, com acesso restrito, cifragem, retenção aprovada e sem links públicos. Não usar artefactos públicos de CI como cofre de backup.
3. **Manifesto:** registar data UTC, ambiente, commit, tipo de cópia, tamanho, SHA-256, resultado da validação e identificador não sensível. Nunca incluir dados pessoais, tokens ou credenciais.
4. **Monitorização:** detetar ausência de backup esperado, workflow falhado, tamanho inesperado, hash divergente ou erro na verificação.
5. **Classificação:** distinguir falha de backup, falha de integridade, indisponibilidade de aplicação e suspeita de corrupção. Não tratar todos os alertas como autorização para restaurar.
6. **Pré-verificações:** verificar projeto de destino por allowlist explícita, confirmar que não é produção, validar assinatura/hash e confirmar que existe um backup íntegro anterior.
7. **Restauro isolado:** apenas após pré-verificações, restaurar PostgreSQL em homologação. Storage é restaurado por processo separado e validado por contagem/tamanho/hash.
8. **Testes pós-restauro:** verificar estrutura, constraints, funções, triggers, RLS, relações entre instituições, login e testes negativos de isolamento entre duas instituições fictícias.
9. **Resultado:** se qualquer verificação falhar, parar, preservar logs sem segredos e alertar o responsável. Não repetir automaticamente em ciclo infinito.
10. **Produção:** criar incidente e pedir autorização explícita. Não executar failover, sobrescrita ou restauro de produção automaticamente.

## Regras de disparo

| Condição | Ação automática permitida |
|---|---|
| Backup não produzido dentro da janela aprovada | Alerta; repetir apenas a tarefa de backup de forma limitada |
| Hash não corresponde ao manifesto | Quarentena da cópia e alerta; nunca restaurar essa cópia |
| Dump inválido ou incompleto | Marcar inválido e procurar cópia anterior verificada |
| Falha de teste de restauro em homologação | Parar, guardar evidência e alertar; não promover para produção |
| Aplicação indisponível, mas backup íntegro | Diagnóstico e teste isolado; não presumir que a causa é corrupção de dados |
| Suspeita de ataque/ransomware ou alterações maliciosas | Suspender automação destrutiva, preservar evidências e exigir decisão humana |
| Produção requer restauro | Bloqueio por defeito até aprovação humana explícita |

## Separação de componentes

- **PostgreSQL:** backup e restauro por ferramentas compatíveis com o formato/versão.
- **Supabase Storage:** exportar objetos separadamente; validar caminhos, tamanhos e hashes. Não substituir ficheiros atuais sem política de recuperação aprovada.
- **Auth/configuração:** documentar e validar separadamente. Nunca guardar segredos em GitHub nem no manifesto.
- **Edge Functions e aplicação:** identificar commit/versão; restaurar o código versionado por fluxo de implantação separado.
- **Dados fiscais/financeiros:** não emitir documentos nem registar pagamentos durante os testes de restauro.

## Salvaguardas obrigatórias

- Allowlist explícita do host de homologação e bloqueio do identificador de produção conhecido.
- Credenciais mínimas, guardadas em secrets seguros; nunca expostas em argumentos/logs.
- Hash e validação do ficheiro antes do restauro.
- Ambiente isolado sem email/SMS/pagamentos reais nem integrações externas ativas.
- Limite de tentativas e intervalo de espera; prevenção de ciclos de recuperação.
- Logs de auditoria sem dados pessoais desnecessários.
- Cópia de segurança do ambiente de homologação antes de cada ensaio destrutivo.
- Aprovação humana e plano de reversão para qualquer operação em produção.

## Decisões pendentes antes de ativar

- [ ] Confirmar o mecanismo suportado para exportar PostgreSQL e Storage no projeto/versão atuais.
- [ ] Confirmar se o plano Supabase permite a automação pretendida e quais são os limites/custos.
- [ ] Escolher a localização exata do destino privado associado ao projeto e as regras de acesso.
- [ ] Definir frequência, retenção, RPO/RTO, responsável e canal de alertas.
- [ ] Configurar secrets apenas no ambiente seguro e testar credenciais de menor privilégio.
- [ ] Implementar workflow de backup e verificação, com execução manual inicial.
- [ ] Implementar teste de restauro em homologação e demonstrar evidência de sucesso.
- [ ] Aprovar política de retenção e recuperação antes de qualquer execução em produção.

## Critério de ativação

Só considerar “restauração automática em homologação ativa” depois de workflow executado com sucesso, backup PostgreSQL e Storage verificados, restauro isolado concluído e testes de segurança aprovados. Até lá, este documento é um plano, não uma garantia operacional.
