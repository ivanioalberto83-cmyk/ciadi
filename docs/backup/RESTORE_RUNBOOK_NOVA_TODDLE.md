# NOVA TODDLE ESCOLAR — Runbook proposto de restauro

**Estado:** procedimento de referência; não executado nem aprovado para produção.  
**Objetivo:** recuperar a aplicação em ambiente isolado e provar que a cópia é utilizável sem afetar dados atuais.

## Proibições

- Nunca restaurar por cima de produção durante um ensaio.
- Nunca usar dados reais para um teste funcional quando dados fictícios bastarem.
- Não executar comandos destrutivos sem confirmação do ambiente e do destino.
- Não considerar o hash isoladamente prova de que a base de dados está funcional.
- Não guardar credenciais ou chaves em comandos copiados para logs, tickets ou GitHub.

## Pré-requisitos

- Autorização escrita para o ensaio e responsável designado.
- Projeto de homologação vazio, separado da produção e com região/configuração registadas.
- Backup cifrado e chave disponível através do processo seguro aprovado.
- Manifesto e hash SHA-256 originais.
- Versão exata do código/commit e dependências correspondentes.
- Exportação de Storage e lista de objetos/tamanhos.
- Plano para eliminar os dados de teste ao terminar, sujeito a aprovação.

## Automatização disponível no repositório

Foi adicionado o script `scripts/backup/restore-nova-toddle.ps1`. É um executor controlado de restauro PostgreSQL, não um serviço autónomo de recuperação: exige um ficheiro de backup já obtido, hash SHA-256 esperado, ferramentas PostgreSQL e destino de homologação explicitamente autorizado.

Variáveis de ambiente necessárias, definidas apenas no ambiente seguro:
- `NOVA_TODDLE_HOMOLOGATION_DATABASE_URL`: URI de ligação à base de homologação.
- `NOVA_TODDLE_HOMOLOGATION_ALLOWED_HOSTS`: lista separada por vírgulas de hosts aprovados para homologação.

Exemplo de simulação, sem escrever na base de dados:

```powershell
$env:NOVA_TODDLE_HOMOLOGATION_DATABASE_URL = '<URI segura de homologação>'
$env:NOVA_TODDLE_HOMOLOGATION_ALLOWED_HOSTS = '<host exato de homologação>'
$sha = (Get-FileHash '.\\backup.dump' -Algorithm SHA256).Hash
.\\scripts\\backup\\restore-nova-toddle.ps1 -Environment Homologacao -BackupPath '.\\backup.dump' -ExpectedSha256 $sha -ConfirmRestore -WhatIf
```

Para executar sem `-WhatIf`, exige-se revisão do destino, aprovação operacional e confirmação de que a base é descartável e está isolada. O script não faz download automático, não recupera Storage e não certifica a aplicação após o restauro.

## Procedimento controlado

1. **Confirmar alvo:** verificar o identificador do projeto de homologação por dois meios independentes. Parar se qualquer valor apontar para produção.
2. **Validar artefactos:** verificar ficheiros, tamanho esperado, SHA-256 e manifesto. Se houver divergência, não restaurar.
3. **Preparar isolamento:** impedir tráfego de utilizadores, integrações externas e envio de emails/SMS reais durante o ensaio.
4. **Restaurar PostgreSQL:** usar procedimento compatível com o formato de exportação e a versão de destino; registar erros sem revelar segredos.
5. **Restaurar Storage:** importar os objetos separadamente, mantendo os caminhos/IDs exigidos pela aplicação e validando contagens e tamanhos.
6. **Validar estrutura:** confirmar tabelas, constraints, funções, triggers, políticas RLS e permissões. Não assumir que um dump de dados contém configuração completa do projeto.
7. **Validar dados:** verificar contagens esperadas, chaves estrangeiras, órfãos e relações entre instituição, alunos, matrículas, cobranças e documentos fiscais.
8. **Validar segurança:** executar o plano tests/security/tenant-isolation-test-plan.md com duas instituições fictícias.
9. **Validar aplicação:** login, recuperação de palavra-passe, navegação, operações autorizadas, PDF/exportação aplicável e ausência de chamadas a integrações reais.
10. **Registar resultado:** duração, versão, contagens não pessoais, erros, checksums e casos de teste aprovados/reprovados.
11. **Limpar:** após revisão, remover ou reter o ambiente de teste conforme política aprovada; confirmar que não houve alterações na produção.

## Critérios de sucesso

- Hash dos artefactos corresponde ao manifesto antes do restauro.
- Base de dados e Storage são recuperados separadamente e validados.
- Integridade relacional sem anomalias não explicadas.
- Testes de isolamento entre instituições passam.
- Login e funções críticas de negócio passam em homologação.
- Nenhum email, SMS, pagamento ou documento fiscal real foi enviado/emitido.
- Evidência revista por segunda pessoa ou responsável designado.

## Registo do ensaio

| Campo | Valor a preencher |
|---|---|
| Identificador do ensaio | |
| Data/hora UTC | |
| Responsável | |
| Ambiente de destino (ID não secreto) | |
| Commit/versão da aplicação | |
| Backup PostgreSQL / SHA-256 | |
| Backup Storage / SHA-256 ou manifesto | |
| Duração total | |
| Resultado dos testes | |
| Anomalias / ações corretivas | |
| Revisão/aprovação | |

## Após o ensaio

Um ensaio aprovado demonstra recuperação apenas para o backup, versão e ambiente testados. Repetir após alterações significativas de esquema, configuração ou fluxo de autenticação. Só depois de aprovar este runbook e o destino se pode considerar automatização; qualquer restauro de produção requer autorização explícita independente.
