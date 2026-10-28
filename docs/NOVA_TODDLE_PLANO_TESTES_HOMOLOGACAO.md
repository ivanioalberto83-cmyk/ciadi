# NOVA TODDLE ESCOLAR — Plano de testes de homologação
Data: 2026-10-28  
Branch: `nova-toddle-escolar`  
Regra: usar apenas ambiente de homologação e dados fictícios. Não testar operações destrutivas na produção.

## Pré-condições
- [ ] Ambiente de homologação separado ou janela de testes aprovada, com backup e restauração documentados.
- [ ] Duas instituições fictícias (Escola A e Escola B), cada uma com utilizador administrador e contabilista.
- [ ] Perfis de aluno/encarregado e utilizador sem privilégios.
- [ ] Credenciais de teste e tokens não incluídos nos registos de teste.
- [ ] A versão da Edge Function PDF corrigida na branch está implantada apenas no ambiente de homologação antes do teste de PDF.

## Segurança e isolamento multiempresa
| ID | Teste | Resultado esperado |
|---|---|---|
| SEC-01 | Utilizador A consulta alunos, cobranças, pagamentos e documentos da Escola A | Apenas registos da Escola A |
| SEC-02 | Utilizador A tenta ler registo da Escola B por ID direto | Sem dados / acesso negado |
| SEC-03 | Utilizador A tenta atualizar ou eliminar registo da Escola B | Operação negada e sem alteração |
| SEC-04 | Utilizador A envia `instituicao_id` da Escola B a uma RPC | RPC rejeita a operação |
| SEC-05 | Utilizador autenticado sem papel financeiro chama RPC fiscal/financeira | Operação negada |
| SEC-06 | Utilizador anónimo tenta ler tabelas privadas e invocar funções privilegiadas | Sem acesso |
| SEC-07 | Alteração de instituição/ID em payloads e referências cruzadas | Sem leitura, escrita ou associação entre instituições |
| SEC-08 | Rever as seis tabelas com RLS sem políticas | Acesso pretendido documentado; não adicionar políticas genéricas |

## Faturação, pagamentos e contabilidade
| ID | Teste | Resultado esperado |
|---|---|---|
| FIN-01 | Criar cobrança com aluno pertencente à mesma instituição | Criada e visível apenas nessa instituição |
| FIN-02 | Criar cobrança com aluno/responsável de outra instituição | Rejeitada |
| FIN-03 | Registar pagamento válido e parcial | Saldo e estado corretos; sem duplicação |
| FIN-04 | Pagamento acima do saldo ou valor zero/negativo | Rejeitado segundo a regra de negócio aprovada |
| FIN-05 | Emitir documento com série de outra instituição ou exercício errado | Rejeitado |
| FIN-06 | Emitir documento sem cliente/linhas válidas | Rejeitado |
| FIN-07 | Contabilizar documento elegível | Débito = crédito; uma contabilização por documento |
| FIN-08 | Repetir contabilização do mesmo documento | Não duplica lançamento |
| FIN-09 | Fechar período com lançamentos desequilibrados ou pendências | Fecho bloqueado |
| FIN-10 | Verificar PDF de documento fiscal | Linhas ligadas por `documento_id`; PDF e registo privado acessíveis apenas a utilizadores autorizados |

## SAF-T
| ID | Teste | Resultado esperado |
|---|---|---|
| TAX-01 | Exportação tipo F | Tipo validado pela função; ficheiro e checksum registados |
| TAX-02 | Exportação tipo I | Tipo validado pela função; ficheiro e checksum registados |
| TAX-03 | Exportação tipo R | Tipo validado pela função; ficheiro e checksum registados |
| TAX-04 | Tipo inválido ou período invertido | Pedido rejeitado |
| TAX-05 | Utilizador de Escola A envia instituição B | Pedido rejeitado |
| TAX-06 | XML de cada tipo | Validado contra o esquema/requisitos oficiais aplicáveis, não apenas XML bem formado |
| TAX-07 | Comparar totais, documentos, notas, IVA e lançamentos com os dados fonte | Reconciliação documentada sem diferenças inexplicadas |

## RH e Aprovisionamento
- [ ] Criar, editar, consultar e desativar colaborador; verificar persistência após novo login.
- [ ] Restringir dados de RH por instituição e papel.
- [ ] Criar pedido de compra, aprovar/rejeitar segundo papel autorizado e registar receção.
- [ ] Validar stock/movimentos, fornecedor, totais e ligações financeiras.
- [ ] Confirmar auditoria de alterações e tratamento de erros sem mensagens falsas de sucesso.

## Backups, publicação e evidências
- [ ] Backup da base de dados e Storage concluído, com hash/manifesto.
- [ ] Restauração feita em ambiente separado e dados essenciais conferidos.
- [ ] Testes de login, sessão expirada, recuperação de erro e permissões.
- [ ] Registar para cada teste: versão/commit, data, utilizador de teste, resultado, evidência e issue.
- [ ] Nenhum teste aprovado por mera presença de botão ou mensagem visual: confirmar resultado persistido no backend.

## Critério de saída
Homologação técnica só avança quando todos os testes críticos de segurança, isolamento, faturação, pagamentos, contabilização, SAF-T e restauração passam com evidência. Certificação ou homologação oficial AGT é uma etapa distinta e só pode ser declarada com prova formal válida.
