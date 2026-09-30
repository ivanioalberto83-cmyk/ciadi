# CIADI+ — correções preparadas para APK v13

Base: ciadi+.zip presente no repositório.

Correções:
- autenticação: a palavra-passe deixa de ser alterada por trim;
- chat: REST, envio e Realtime alimentam o mesmo StateFlow observado pela UI;
- testes: o teste unitário não depende de uma chamada de rede externa;
- versão: versionCode 13 / versionName 1.1.0, mantendo o applicationId existente;
- identidade: paleta CIADI baseada no site oficial e ícone vetorial laranja/amarelo/castanho;
- build: JDK 17 + Gradle 9.3.1 no GitHub Actions;
- .env permanece fora do repositório.

O ZIP original é preservado; o workflow extrai e aplica o patch antes da compilação.
