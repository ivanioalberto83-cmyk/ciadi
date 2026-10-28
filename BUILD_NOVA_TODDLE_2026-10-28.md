# Pedido de build — NOVA TODDLE ESCOLAR Windows

- Data do pedido: 2026-10-28
- Branch de aplicação: `nova-toddle-escolar`
- Produto: `NOVA-TODDLE-ESCOLAR-Setup-1.0.0.exe`
- Pipeline: `.github/workflows/build-nova-toddle-windows.yml`
- Testes obrigatórios: `npm test`, `npm run check`, criação e validação de `release/*.exe`
- Artefacto esperado: `nova-toddle-escolar-windows-installer`

Este registo provoca o workflow de build através do evento push configurado. O instalador só será considerado pronto depois de o workflow terminar com sucesso e o artefacto ser verificado. Este pedido não executa migrações nem altera o projeto Supabase.
