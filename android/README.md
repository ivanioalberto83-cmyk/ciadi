# CIADI+ Android — Clínica Virtual

Módulo Android base para ligar o CIADI+ à Clínica Virtual.

Fluxo:
CIADI+ → Agendamento → Clínica Virtual → sala.html?agendamento_id=ID → ciadi-video-token → LiveKit.

Este módulo não altera Contabilidade, SAF-T ou faturação.

Segurança:
- usar apenas a publishable key no cliente;
- nunca colocar service_role no APK;
- a autorização do agendamento permanece no Supabase/Edge Function.
