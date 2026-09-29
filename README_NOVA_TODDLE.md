# NOVA TODDLE ESCOLAR

Aplicação web inicial da NOVA TODDLE ESCOLAR, separada do projeto CIADI.

## Backend
- Supabase: `rojyxfjaidyvtmsmefcf`
- URL: https://rojyxfjaidyvtmsmefcf.supabase.co
- Autenticação: Supabase Auth
- Dados: tabelas escolares existentes no projeto NOVA TODDLE

## Funcionalidades desta primeira versão
- Login real por Supabase Auth
- Identificação do utilizador através de `public.perfis`
- Saudação personalizada pelo primeiro nome
- Dashboard inicial
- Contadores de alunos, professores, turmas e matrículas
- Módulos de alunos, professores, académico e comunicação
- Área NOVA AI
- Leitura protegida pelas políticas RLS existentes
- Layout responsivo para computador e telemóvel

## Separação de projetos
Este código NÃO reutiliza a arquitetura clínica do CIADI. O repositório GitHub foi utilizado apenas porque é o repositório atualmente conectado ao projeto Supabase NOVA TODDLE.

## Próximos passos
1. Associar a instituição ao perfil administrador.
2. Implementar cadastro/gestão de instituição.
3. Construir os dashboards completos por função.
4. Integrar a chamada real à Edge Function `nova-ai`.
5. Criar migrations/configuração Supabase no repositório para sincronização GitHub.
6. Testar Auth, RLS e fluxos de cada perfil.
