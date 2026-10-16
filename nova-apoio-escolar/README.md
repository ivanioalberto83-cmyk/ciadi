# NOVA Apoio Escolar — protótipo separado

## Objetivo
Criar uma aplicação própria para apoio psicológico escolar e comunidade, separada dos módulos administrativos do NOVA Toddle School.

## Módulos previstos
1. Psicologia
2. Cursos
3. Palestras e Workshops
4. SOS Escolar (reutilizar o SOS existente, sem duplicar denúncias)
5. Chat
6. Jornal Escolar

## Estado desta entrega
- Protótipo visual responsivo em HTML autónomo.
- Navegação funcional entre seis módulos.
- Sem submissão ou persistência de dados.
- Sem ligação ativa ao Supabase.
- Nenhuma alteração à base de dados ou à aplicação administrativa.
- Os ecrãs são apenas estrutura inicial; autenticação, RLS, tabelas e operações reais serão implementadas após validação de permissões.

## Segurança antes de ativar
- Não expor dados psicológicos a professores, famílias ou administradores sem autorização explícita.
- Definir acesso por instituição, função e relação legítima com o caso.
- Não guardar dados clínicos no chat geral.
- Rever RLS, políticas de Storage e funções/triggers SOS existentes.
- Testar apenas com dados fictícios numa área de desenvolvimento.
- Não incluir chaves Supabase secret/service_role no navegador.
- O sistema não deve diagnosticar automaticamente; casos urgentes precisam de fluxo de encaminhamento humano.

## Abrir
Abrir `index.html` num navegador. Este ficheiro é um protótipo local e não está publicado.
