# NOVA TODDLE ESCOLAR — Plano de testes de isolamento entre instituições

**Ambiente obrigatório:** projeto Supabase de homologação separado de produção.  
**Dados:** fictícios, sem dados reais de alunos, encarregados, profissionais ou pagamentos.  
**Objetivo:** comprovar que autenticação, RLS e funções não permitem acesso cruzado entre instituições.

## Preparação

Criar duas instituições de teste: **ESCOLA-A** e **ESCOLA-B**. Em cada uma criar, pelo fluxo normal, um administrador institucional, um profissional, um encarregado e um aluno fictícios. Criar matrículas, presenças, avaliações, cobranças e documentos fictícios onde os módulos permitirem. Guardar os IDs de teste num registo local seguro; não publicar tokens ou dados pessoais no GitHub.

Usar sessão de cada papel real e chamadas através da aplicação/API normal. Não utilizar `service_role` para simular um utilizador. Se forem necessárias consultas administrativas para preparar os dados, mantê-las separadas dos testes de autorização.

## Matriz de testes negativos

| ID | Sessão de origem | Ação sobre recurso da outra instituição | Resultado esperado |
|---|---|---|---|
| TEN-01 | Profissional A | Ler aluno, matrícula, presença ou avaliação B | Negado ou resultado vazio, conforme contrato da API |
| TEN-02 | Encarregado A | Consultar ou alterar dados de aluno B | Negado; relação de encarregado não pode ser falsificada |
| TEN-03 | Administrador A | Listar, editar ou apagar dados institucionais B | Negado |
| TEN-04 | Utilizador A | Inserir registo com `instituicao_id` de B | Negado por política ou validação do servidor |
| TEN-05 | Utilizador A | Alterar um registo próprio para `instituicao_id` de B | Negado |
| TEN-06 | Utilizador de baixo privilégio | Alterar o próprio `role` para `super_admin` ou administrador | Negado; a sessão continua com os privilégios originais |
| TEN-07 | Utilizador A | Invocar `nova_criar_cobranca` com aluno/cliente de B | Negado; não deve ser criada cobrança |
| TEN-08 | Utilizador A | Invocar `nova_registar_pagamento` ou `nova_vincular_documento_cobranca` com cobrança/documento de B | Negado; sem efeitos parciais |
| TEN-09 | Utilizador A | Invocar `fiscal_emitir_documento` com documento de origem de B ou autor forjado | Negado; autor vem da identidade validada no servidor |
| TEN-10 | Utilizador sem papel autorizado | Invocar `nova_atualizar_estado_cobranca` | Negado |
| TEN-11 | Sessão expirada/ausente | Invocar funções de negócio e `nova-ai` | 401/403 ou erro equivalente; sem dados nem efeitos |
| TEN-12 | Origem web não autorizada | Fazer preflight e chamar `nova-ai` | CORS não autoriza a origem; a autorização não depende apenas de CORS |
| TEN-13 | Utilizador A | Consultar Storage privado com caminho/ID de ficheiro B | Negado |
| TEN-14 | Administrador A | Operar sobre tabela sem políticas RLS | Comportamento deny-all confirmado ou requisito documentado; não assumir que RLS ativo significa acesso funcional |

## Testes positivos para evitar bloqueios excessivos

- Cada utilizador consegue executar as ações autorizadas dentro da própria instituição.
- Administrador institucional não se torna automaticamente administrador global.
- Um encarregado só acede aos alunos associados de forma validada.
- A cobrança e o documento fiscal permanecem ligados a entidades da mesma instituição.
- O fluxo de login, recuperação de palavra-passe e confirmação de email continua funcional.
- Operações de cobrança/pagamento são idempotentes ou impedem duplicação segundo regra funcional documentada.

## Evidência a registar

Para cada caso, anotar: ID do teste, data/hora, ambiente, papel usado, recurso fictício, ação, resultado esperado, resultado real, HTTP/SQLSTATE quando disponível, efeito observado e link para execução CI. Redigir ou omitir tokens, emails de teste se não forem necessários e qualquer segredo. Não registar conteúdo clínico ou dados reais.

## Critério de aprovação

- 100% dos testes negativos TEN-01 a TEN-13 negados sem alterações parciais.
- Os testes positivos de cada papel passam.
- Não há regressões no fluxo de autenticação.
- Toda exceção tem justificação aprovada e teste específico.
- A evidência é revista antes de qualquer proposta de migração.

**Importante:** este ficheiro define testes; não afirma que os testes foram executados. Não usar em produção nem tentar aceder a dados reais de outra instituição.
