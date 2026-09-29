# NOVA TODDLE ESCOLAR — Arquitetura de Módulos 1.0

## Auditoria atual

### Já existe no banco
- Gestão da instituição e multi-tenant
- Anos letivos e estrutura curricular
- Alunos, encarregados e vínculos
- Professores e perfis
- Turmas, disciplinas e horários
- Matrículas
- Presenças
- Avaliações, resultados e progresso
- Portfolios e objetivos de aprendizagem
- Admissões
- Comunicação, mensagens e notificações
- Eventos/comunicados
- Documentos escolares
- Financeiro escolar
- Contabilidade/fiscalidade e preparação AGT
- NOVA AI
- SOS/Denúncias
- Auditoria
- SaaS: planos, assinaturas, suporte, manutenção e atualizações

### Módulos identificados como próximos
1. Biblioteca
2. Transporte escolar
3. Inventário e património
4. RH e funcionários
5. Férias/licenças
6. Saúde/enfermaria escolar
7. Portaria e visitantes
8. Alumni/ex-alunos
9. Atividades extracurriculares e clubes
10. Compras/fornecedores
11. Cantina/refeitório
12. Gestão de salas e instalações
13. Calendário escolar central
14. Relatórios/MIS
15. LMS/e-learning
16. Gestão de comportamento e acompanhamento
17. Certificados e declarações
18. Portal dedicado do professor
19. Portal dedicado do aluno
20. Portal dedicado da família

## Princípio de arquitetura

Todos os módulos devem usar:
- instituicao_id como tenant
- RLS
- perfis/role + permissões
- ano letivo quando aplicável
- auditoria de operações sensíveis
- notificações quando houver eventos relevantes
- o mesmo cadastro único do aluno

## Ordem recomendada

### Fase A — Operação diária
Biblioteca → Transporte → Inventário → RH → Portaria → Saúde

### Fase B — Vida escolar
Atividades/Clubes → Comportamento → Certificados → Alumni → Cantina

### Fase C — Inteligência
Relatórios/MIS → indicadores → dashboards → NOVA AI contextual

### Fase D — Experiência
Portal Professor → Portal Aluno → Portal Família → app móvel

## Regra

Não criar módulos isolados. Cada módulo deve ligar-se ao cadastro único de alunos, famílias, funcionários, turmas e ano letivo.
