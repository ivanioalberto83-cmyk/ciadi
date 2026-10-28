# Plano de remediação RLS — isolamento multiempresa NOVA TODDLE

**Estado:** proposta para revisão, não executada.  
**Branch:** `audit/nova-toddle-fases-1-4`  
**Produção:** nenhuma alteração autorizada ou realizada.

## Objetivo
Impedir que um administrador ou utilizador de uma instituição aceda ou modifique dados de outra. A autorização deve verificar a instituição real derivada da sessão e todas as relações relacionadas, e não confiar em IDs enviados pelo cliente.

## Correções propostas

### A. Professores
- Rever e substituir a política ampla `tenant admins manage teachers`, que atualmente permite todas as operações com `private.is_tenant_admin()` sem uma restrição institucional explícita.
- Criar uma política institucional que permita gerir apenas registos `professores` cujo `perfil_id` esteja associado a um registo `perfis` da instituição atual.
- Para INSERT e UPDATE, validar também o perfil que fica associado ao professor.
- Rever a política `staff manage teachers` em conjunto com todas as políticas da tabela: políticas permissivas combinam-se por OR.
- Antes de definir o papel autorizado, rever `private.is_tenant_admin()`: a definição atual inclui school_admin, principal, academic_director, accountant, reception e staff. Não presumir que todos devem gerir professores.

### B. Relação aluno–encarregado
- Substituir a política ampla `staff manage student guardians`.
- Para INSERT, UPDATE e DELETE, validar que o aluno e o encarregado existem e pertencem ambos à instituição atual.
- Preservar o acesso de leitura legítimo dos encarregados apenas aos alunos associados por relação validada.
- Testar adulteração de `aluno_id` e `encarregado_id`, incluindo tentativa de associar aluno de A a encarregado de B.

### C. Perfis e papéis — bloqueio independente
- A política `staff manage profiles` permite operações amplas na tabela `perfis`, que contém `role` e `instituicao_id`.
- Não alterar apenas a política RLS e assumir que o papel ficou protegido: o controlo de UPDATE por linha não restringe, por si só, quais colunas podem ser atualizadas.
- Mapear grants/column privileges, trigger functions, signup e onboarding. Preparar proteção específica para impedir autoelevação, atribuição de `super_admin` por administradores institucionais e transferência de utilizadores entre instituições.
- A regra proposta deve preservar o fluxo legítimo de criação de conta/perfil, que ainda requer testes antes de escolher a implementação.

## Testes obrigatórios em homologação

Usar duas organizações fictícias A e B e sessões de utilizadores reais de teste. Não usar service_role para simular utilizadores.

1. Administrador A lista/edita/apaga professores A: autorizado conforme papel.
2. Administrador A tenta ler/editar/apagar professor B: negado.
3. Administrador A tenta associar professor a perfil B: negado.
4. Administrador A associa aluno A a encarregado A: autorizado se o papel permitir.
5. Administrador A tenta associar aluno A a encarregado B ou aluno B a encarregado A: negado.
6. Utilizador tenta alterar o próprio `role` para `super_admin`: negado.
7. Administrador A tenta atribuir `super_admin` ou mudar utilizador para instituição B: negado.
8. Fluxos legítimos de signup, recuperação de palavra-passe, criação de utilizador e administração de instituição continuam a funcionar.
9. Repetir testes para SELECT, INSERT, UPDATE e DELETE; verificar que falhas não deixam efeitos parciais.
10. Regressão de faturação, matrícula, notificações e relatórios.

## Sequência segura
1. Rever este plano e confirmar matriz de papéis.
2. Preparar proposta SQL isolada com rollback, sem colocá-la em migrations automáticas.
3. Rever sintaxe e compatibilidade com o esquema real.
4. Aplicar somente numa base de homologação descartável.
5. Executar e guardar evidências de todos os testes.
6. Só depois de aprovação explícita avaliar janela de produção com backup restaurável e rollback testado.

## Limites
Este documento é um plano. Não modifica RLS, grants, funções, Auth ou dados. Não declara os riscos corrigidos nem autoriza publicação.
