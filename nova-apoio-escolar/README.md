# NOVA Apoio Escolar — aplicação independente em desenvolvimento

## Objetivo
Criar uma aplicação própria para apoio psicológico escolar e comunidade, separada dos módulos administrativos do NOVA Toddle School.

## Módulos previstos
1. Psicologia
2. Cursos
3. Palestras e Workshops
4. SOS Escolar (reutilizar o SOS existente, sem duplicar denúncias)
5. Chat
6. Jornal Escolar

## O que está implementado nesta fase
- Protótipo visual responsivo em HTML autónomo.
- Navegação entre os seis módulos.
- Ecrã de autenticação com Supabase Auth.
- Validação do perfil autenticado na tabela `perfis` e exigência de `ativo = true` e `instituicao_id`.
- Botão de terminar sessão.
- A aplicação não carrega dados de alunos, denúncias ou registos clínicos nesta fase.

## Limites importantes
- O login usa o projeto Supabase configurado no NOVA Toddle School atual. A autenticação e a leitura do próprio perfil são operações reais no projeto existente; não foram feitas alterações de esquema, políticas ou dados.
- As funções dos módulos continuam a ser apenas estrutura visual. Nenhum formulário do protótipo cria ou altera registos.
- O acesso à interface não substitui políticas RLS. Cada tabela/ação deverá ser protegida no servidor antes de integrar dados reais.
- Não incluir chaves `service_role` ou secret no navegador. A chave publishable é a única chave de cliente utilizada.
- O código deve ser validado em ambiente de desenvolvimento e com contas de teste autorizadas antes de ser disponibilizado a utilizadores.

## Segurança antes de ativar funcionalidades
- Definir permissões por instituição, função e relação legítima com o caso.
- Não expor dados psicológicos a professores, familiares ou administradores sem autorização explícita.
- Não guardar dados clínicos no chat geral.
- Rever RLS, políticas de Storage e funções/triggers SOS existentes.
- Testar apenas com dados fictícios numa área de desenvolvimento.
- Não diagnosticar automaticamente; situações urgentes precisam de encaminhamento humano.

## Abrir
Abrir `index.html` num navegador com acesso à internet. A autenticação depende do Supabase existente; o protótipo ainda não está publicado como serviço independente.
