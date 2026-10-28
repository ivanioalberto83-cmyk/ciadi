# NOVA TODDLE ESCOLAR — Modelo multiempresa com isolamento institucional

**Estado:** especificação de auditoria, não implementada.  
**Branch:** `audit/nova-toddle-fases-1-4`  
**Ambiente de produção:** não alterar durante esta fase.

## 1. Regra fundamental

A NOVA TODDLE é uma plataforma multiempresa/multinstituição. Cada empresa ou instituição registada é uma organização autónoma e constitui um tenant independente. A plataforma pode alojar várias organizações, mas os dados, utilizadores, operações e configurações de cada organização não se misturam.

Esta regra aplica-se a toda a aplicação: interface web, API, base de dados, funções RPC, Edge Functions, ficheiros/Storage, relatórios, exportações, faturação, notificações, pesquisa, IA, auditoria e backups/restauros.

## 2. Limites de autonomia

Cada organização deve ter o seu próprio:
- registo institucional, identificação fiscal e configurações;
- conjunto de utilizadores, papéis e permissões;
- alunos, encarregados, profissionais, turmas, matrículas, presenças e avaliações;
- contratos, candidaturas e documentos de RH;
- cobranças, pagamentos, séries, documentos fiscais, exportações e relatórios;
- assistentes/conversas de IA, denúncias SOS, ficheiros, notificações e registos de auditoria;
- plano, limites, estado de subscrição e preferências, conforme o produto contratado.

Uma empresa não pode consultar, pesquisar, editar, apagar, exportar, faturar, notificar ou inferir dados de outra. Identificadores UUID não constituem autorização. A autorização deve ser validada no servidor e na base de dados.

## 3. Identidade e papéis

- **Utilizador institucional:** pertence a uma organização ativa e recebe permissões limitadas ao seu papel e àquela organização.
- **Administrador institucional:** administra a sua organização, nunca todas as organizações.
- **Papel global de plataforma (`super_admin`):** reservado a operações técnicas globais estritamente necessárias, com acesso controlado, auditável e não confundido com o administrador de uma escola/empresa. Não deve ser atribuível pelo próprio utilizador nem por um administrador institucional.
- A criação de utilizadores e a atribuição de papéis devem derivar da sessão autenticada e de um fluxo administrativo autorizado. O cliente não pode escolher livremente `role`, `instituicao_id` ou identidade de auditoria.
- A alteração de papel, organização, estado e privilégios deve ter validação específica no servidor; edição de dados de perfil não deve conceder implicitamente permissão para alterar privilégios.

## 4. Invariantes de isolamento obrigatórias

1. Cada registo pertencente a uma organização tem um vínculo institucional explícito ou uma relação pai que permita provar a mesma pertença.
2. A instituição autorizada deriva da sessão/perfil validado no servidor; não se confia num `instituicao_id` enviado pelo navegador.
3. Operações de leitura e escrita verificam a instituição para todos os registos relacionados: aluno, encarregado, turma, matrícula, cobrança, pagamento, documento fiscal, ficheiro, conversa e outros.
4. Todas as políticas RLS permissivas são analisadas em conjunto: uma política ampla pode anular, por combinação OR, o efeito prático de uma política mais restrita.
5. Funções `SECURITY DEFINER` e Edge Functions repetem validações de papel, instituição e relações; RLS não é substituto para validar parâmetros de funções privilegiadas.
6. Storage usa buckets/políticas/caminhos que verificam a instituição; nomes de ficheiro e UUID não são prova de autorização.
7. Pesquisa, contagens, dashboards, logs, relatórios, PDF, CSV/XLSX, SAF-T, IA e notificações não podem atravessar o limite institucional.
8. Um restauro de uma organização não pode substituir ou misturar dados de outras organizações; o restauro completo da plataforma exige procedimento separado e aprovação explícita.
9. Não existe partilha entre organizações por defeito. Qualquer futura partilha deverá ser uma funcionalidade explícita, consentida, limitada por finalidade, auditada e testada; não é pressuposta neste modelo.
10. O papel global, as credenciais de serviço e os processos de suporte devem seguir privilégio mínimo, registos de auditoria e acesso controlado.

## 5. Achados da leitura atual que exigem remediação

Na revisão de leitura do Supabase em 2026-10-28:
- `tenant admins manage teachers` permite `ALL` com `private.is_tenant_admin()` sem filtro explícito da instituição na condição da própria política. Por ser permissiva, deve ser avaliada em conjunto com as outras políticas de `professores`.
- `staff manage profiles` permite `ALL` sobre `perfis` com condição baseada em `private.is_tenant_admin()` e instituição atual. A tabela inclui `role`; a consulta não encontrou triggers não internos de proteção. A autoelevação não foi testada, mas é um risco prioritário.
- `staff manage student guardians` permite `ALL` em `aluno_encarregado` sem condição institucional explícita na política. É necessário validar a pertença do aluno e do encarregado.
- `fiscal_emitir_documento` atualmente implantada aceita `p_criado_por` e grava esse argumento, sem validação explícita de que aluno e documento de origem pertencem à instituição indicada. A proposta de correção versionada ainda não está implantada.
- Cinco funções `SECURITY DEFINER` executáveis por `authenticated` e seis tabelas RLS sem políticas foram sinalizadas pelos advisors. Cada caso exige revisão de autorização e intenção; não se devem criar políticas ou revogar privilégios às cegas.

Estas observações são baseadas em consultas de leitura. Não foi executado teste de exploração nem alterada a produção.

## 6. Plano de testes de aceitação

Preparar em homologação isolada duas organizações fictícias, A e B, e contas fictícias com papéis distintos. Não usar chaves `service_role` para simular utilizadores.

Para cada tabela, função, endpoint, ficheiro e exportação:
- A não consegue ler, inserir, editar, apagar, contar ou exportar dados de B;
- B não consegue ler, inserir, editar, apagar, contar ou exportar dados de A;
- adulterar UUID, `instituicao_id`, `perfil_id`, aluno, encarregado, cobrança ou documento não atravessa o limite;
- utilizador não consegue alterar o próprio papel para administrador nem mover-se para outra instituição;
- operações autorizadas dentro da própria organização continuam a funcionar;
- chamadas sem sessão, com sessão expirada ou papel insuficiente são negadas sem efeitos parciais;
- IA, Storage, PDF, relatórios, pesquisa, notificações e backups mantêm o mesmo isolamento;
- tentativas negadas ficam registadas sem expor dados pessoais ou segredos.

**Critério de saída:** todos os testes negativos de isolamento passam sem efeitos laterais; testes positivos por papel passam; evidências são revistas; migrações e mudanças de configuração são aprovadas antes de qualquer aplicação em produção.

## 7. Sequência de implementação

1. Inventariar tabelas, políticas, relações, RPCs, Edge Functions, Storage e rotas que processam dados institucionais.
2. Definir matriz formal de papéis e permissões.
3. Preparar migrações propostas separadas, com rollback e revisão.
4. Testar em ambiente isolado com dados fictícios.
5. Fazer revisão independente e regressão funcional.
6. Só após aprovação explícita, agendar janela de produção, backup verificado e plano de reversão.

## 8. Limites desta especificação

Este documento estabelece o comportamento pretendido; não altera a aplicação, o esquema, RLS, funções, Auth ou dados. Não constitui certificação de segurança nem autorização para publicação.
