-- NOVA TODDLE ESCOLAR — proposta de hardening financeiro
-- Estado: NÃO APLICAR EM PRODUÇÃO sem backup, revisão e testes isolados.
-- Escopo: autoria confiável, isolamento por instituição, vínculo de tipo fiscal e bloqueio de anulação contabilística.

begin;

create or replace function public.fiscal_emitir_documento(
  p_instituicao_id uuid,
  p_serie_id uuid,
  p_tipo text,
  p_cliente_nome text,
  p_cliente_nif text default null,
  p_cliente_email text default null,
  p_cliente_telefone text default null,
  p_aluno_id uuid default null,
  p_data_emissao date default current_date,
  p_data_vencimento date default null,
  p_linhas jsonb default '[]'::jsonb,
  p_criado_por uuid default null,
  p_documento_origem_id uuid default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_doc_id uuid;
  v_numero text;
  v_hash text;
  v_payload text;
  v_linha jsonb;
  v_serie public.series_fiscais%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Não autenticado';
  end if;

  if not exists (
    select 1 from public.perfis p
    where p.id = auth.uid()
      and p.role in ('super_admin','school_admin','accountant','principal','reception')
      and (p.role = 'super_admin' or p.instituicao_id = p_instituicao_id)
  ) then
    raise exception 'Sem autorização para emitir documentos desta instituição';
  end if;

  if p_tipo not in ('fatura','fatura_recibo','recibo','nota_credito','nota_debito','proforma') then
    raise exception 'Tipo de documento fiscal inválido: %', p_tipo;
  end if;
  if coalesce(trim(p_cliente_nome),'') = '' then
    raise exception 'Nome do cliente é obrigatório';
  end if;
  if jsonb_typeof(coalesce(p_linhas,'[]'::jsonb)) <> 'array'
     or jsonb_array_length(coalesce(p_linhas,'[]'::jsonb)) = 0 then
    raise exception 'O documento deve possuir pelo menos uma linha';
  end if;

  if p_aluno_id is not null and not exists (
    select 1 from public.alunos a
    where a.id = p_aluno_id
      and a.instituicao_id = p_instituicao_id
  ) then
    raise exception 'O aluno não pertence à instituição indicada';
  end if;

  if p_documento_origem_id is not null and not exists (
    select 1 from public.documentos_fiscais origem
    where origem.id = p_documento_origem_id
      and origem.instituicao_id = p_instituicao_id
  ) then
    raise exception 'O documento de origem não pertence à instituição indicada';
  end if;

  select * into v_serie
  from public.series_fiscais
  where id = p_serie_id
    and instituicao_id = p_instituicao_id
    and ativa = true
  for update;
  if not found then
    raise exception 'Série fiscal inexistente, inativa ou pertencente a outra instituição';
  end if;
  if v_serie.tipo_documento <> p_tipo then
    raise exception 'A série fiscal não corresponde ao tipo do documento';
  end if;
  if v_serie.exercicio <> extract(year from p_data_emissao)::int then
    raise exception 'A série fiscal não corresponde ao exercício da emissão';
  end if;

  v_numero := public.fiscal_proximo_numero(p_serie_id);

  insert into public.documentos_fiscais(
    instituicao_id, serie_id, aluno_id, tipo, numero, data_emissao, data_vencimento,
    cliente_nome, cliente_nif, cliente_email, cliente_telefone, estado, criado_por, documento_origem_id
  ) values (
    p_instituicao_id, p_serie_id, p_aluno_id, p_tipo, v_numero, p_data_emissao, p_data_vencimento,
    trim(p_cliente_nome), nullif(trim(p_cliente_nif),''), nullif(trim(p_cliente_email),''),
    nullif(trim(p_cliente_telefone),''), 'rascunho', auth.uid(), p_documento_origem_id
  ) returning id into v_doc_id;

  for v_linha in select * from jsonb_array_elements(p_linhas) loop
    if coalesce((v_linha->>'quantidade')::numeric,1) <= 0
       or coalesce((v_linha->>'preco_unitario')::numeric,0) < 0
       or coalesce((v_linha->>'desconto')::numeric,0) < 0
       or coalesce((v_linha->>'taxa_imposto')::numeric,0) < 0 then
      raise exception 'Quantidade, preço, desconto ou taxa fiscal inválidos';
    end if;
    insert into public.documentos_fiscais_linhas(
      documento_id, descricao, quantidade, preco_unitario, desconto, taxa_imposto, unidade, codigo_item
    ) values (
      v_doc_id, coalesce(v_linha->>'descricao',''),
      coalesce((v_linha->>'quantidade')::numeric,1),
      coalesce((v_linha->>'preco_unitario')::numeric,0),
      coalesce((v_linha->>'desconto')::numeric,0),
      coalesce((v_linha->>'taxa_imposto')::numeric,0),
      coalesce(v_linha->>'unidade','UN'),
      nullif(v_linha->>'codigo_item','')
    );
  end loop;

  perform public.fiscal_calcular_documento(v_doc_id);

  select jsonb_build_object(
    'id',d.id,'instituicao_id',d.instituicao_id,'serie_id',d.serie_id,'tipo',d.tipo,
    'numero',d.numero,'data_emissao',d.data_emissao,'cliente_nome',d.cliente_nome,
    'cliente_nif',d.cliente_nif,'subtotal',d.subtotal,'desconto',d.desconto,
    'imposto',d.imposto,'total',d.total
  )::text into v_payload
  from public.documentos_fiscais d where d.id = v_doc_id;

  v_hash := encode(digest(v_payload,'sha256'),'hex');

  update public.documentos_fiscais
  set estado='emitido', emitido_em=now(), hash_fiscal=v_hash, hash_algoritmo='SHA-256'
  where id=v_doc_id;

  insert into public.fiscal_auditoria(instituicao_id,documento_fiscal_id,operacao,utilizador_id,dados)
  values(p_instituicao_id,v_doc_id,'EMISSAO',auth.uid(),
         jsonb_build_object('numero',v_numero,'hash_fiscal',v_hash));

  return v_doc_id;
end;
$function$;

create or replace function public.nova_vincular_documento_cobranca(
  p_cobranca_id uuid,
  p_documento_fiscal_id uuid,
  p_tipo text
) returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  c public.cobrancas_escolares%rowtype;
  d public.documentos_fiscais%rowtype;
begin
  if auth.uid() is null then raise exception 'Não autenticado'; end if;

  select * into c from public.cobrancas_escolares
  where id = p_cobranca_id for update;
  if not found then raise exception 'Cobrança não encontrada'; end if;

  select * into d from public.documentos_fiscais where id = p_documento_fiscal_id;
  if not found or d.instituicao_id <> c.instituicao_id then
    raise exception 'Documento fiscal inválido ou pertencente a outra instituição';
  end if;

  if not exists (
    select 1 from public.perfis p
    where p.id = auth.uid()
      and p.role in ('super_admin','school_admin','accountant','principal','reception','staff')
      and (p.role = 'super_admin' or p.instituicao_id = c.instituicao_id)
  ) then raise exception 'Sem autorização'; end if;

  if p_tipo = 'fatura' then
    if d.tipo not in ('fatura','fatura_recibo') then
      raise exception 'O documento selecionado não é uma fatura';
    end if;
    update public.cobrancas_escolares
    set documento_fiscal_id=d.id, documento_fatura_id=d.id,
        atualizado_em=now(), atualizado_por=auth.uid()
    where id=c.id;
  elsif p_tipo = 'recibo' then
    if d.tipo not in ('recibo','fatura_recibo') then
      raise exception 'O documento selecionado não é um recibo';
    end if;
    update public.cobrancas_escolares
    set documento_recibo_id=d.id, atualizado_em=now(), atualizado_por=auth.uid()
    where id=c.id;
  else
    raise exception 'Tipo inválido';
  end if;
end;
$function$;

create or replace function public.nova_registar_pagamento(
  p_cobranca_id uuid,
  p_valor numeric,
  p_data_pagamento date,
  p_metodo_pagamento_id uuid,
  p_referencia text
) returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  c public.cobrancas_escolares%rowtype;
  v_id uuid;
  pago numeric;
begin
  if auth.uid() is null then raise exception 'Não autenticado'; end if;

  select * into c from public.cobrancas_escolares
  where id=p_cobranca_id for update;
  if not found then raise exception 'Cobrança não encontrada'; end if;

  if not exists (
    select 1 from public.perfis p
    where p.id=auth.uid()
      and p.role in ('super_admin','school_admin','accountant','principal','reception','staff')
      and (p.role='super_admin' or p.instituicao_id=c.instituicao_id)
  ) then raise exception 'Sem autorização'; end if;

  if p_valor is null or p_valor <= 0 then
    raise exception 'Valor de pagamento inválido';
  end if;
  if p_metodo_pagamento_id is not null and not exists (
    select 1 from public.metodos_pagamento m
    where m.id=p_metodo_pagamento_id
      and m.instituicao_id=c.instituicao_id and m.ativo
  ) then raise exception 'Método de pagamento inválido'; end if;

  select coalesce(sum(valor),0) into pago
  from public.pagamentos_escolares where cobranca_id=c.id;
  if pago+p_valor > c.valor then
    raise exception 'Pagamento superior ao saldo da cobrança';
  end if;

  insert into public.pagamentos_escolares(
    instituicao_id,cobranca_id,aluno_id,valor,data_pagamento,metodo_pagamento_id,metodo,referencia
  ) values (
    c.instituicao_id,c.id,c.aluno_id,p_valor,coalesce(p_data_pagamento,current_date),
    p_metodo_pagamento_id,
    coalesce((select nome from public.metodos_pagamento where id=p_metodo_pagamento_id),'transferencia'),
    p_referencia
  ) returning id into v_id;

  update public.cobrancas_escolares
  set estado=case when pago+p_valor >= valor then 'paga' else 'parcial' end,
      atualizado_em=now(), atualizado_por=auth.uid()
  where id=c.id;
  return v_id;
end;
$function$;

create or replace function public.contabilizar_documento_fiscal(p_documento_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  d public.documentos_fiscais%rowtype;
  c public.config_contabil_fiscal%rowtype;
  periodo uuid;
  lanc uuid;
  existente uuid;
  total_debito numeric;
  total_credito numeric;
begin
  select * into d from public.documentos_fiscais where id=p_documento_id for update;
  if not found then raise exception 'Documento fiscal não encontrado'; end if;

  if not exists (
    select 1 from public.perfis p
    where p.id=auth.uid()
      and p.role in ('super_admin','school_admin','accountant','principal')
      and (p.role='super_admin' or p.instituicao_id=d.instituicao_id)
  ) then raise exception 'Sem autorização para contabilizar este documento'; end if;

  if d.estado = 'anulado' then
    raise exception 'Documentos anulados não podem ser contabilizados';
  end if;

  select id into existente from public.contabilizacoes_fiscais
  where documento_fiscal_id=d.id and pagamento_fiscal_id is null
    and tipo in ('venda','nota_credito','nota_debito') limit 1;
  if existente is not null then return existente; end if;

  select * into c from public.config_contabil_fiscal
  where instituicao_id=d.instituicao_id and ativo=true;
  if not found then raise exception 'Configuração contabilística fiscal não definida para a instituição'; end if;
  if d.estado not in ('emitido','pago','parcial','vencido') then
    raise exception 'Só documentos emitidos e válidos podem ser contabilizados';
  end if;
  if d.tipo in ('proforma','recibo') then return null; end if;
  if c.conta_clientes_id is null or c.conta_receita_id is null or c.conta_iva_liquidado_id is null then
    raise exception 'Mapeamento contabilístico incompleto: clientes, receita e IVA são obrigatórios';
  end if;

  insert into public.periodos_contabeis(instituicao_id,ano,mes,estado)
  values(d.instituicao_id,extract(year from d.data_emissao)::int,extract(month from d.data_emissao)::int,'aberto')
  on conflict(instituicao_id,ano,mes) do nothing;

  select id into periodo from public.periodos_contabeis
  where instituicao_id=d.instituicao_id and ano=extract(year from d.data_emissao)::int
    and mes=extract(month from d.data_emissao)::int;

  insert into public.lancamentos_contabeis(
    instituicao_id,periodo_id,data_lancamento,diario,descricao,origem_tipo,origem_id,documento_id,estado
  ) values(d.instituicao_id,periodo,d.data_emissao,'vendas','Documento fiscal '||d.numero,
           'documento_fiscal',d.id,d.id,'lançado')
  returning id into lanc;

  if d.tipo='nota_credito' then
    insert into public.lancamento_linhas_contabeis(lancamento_id,conta_id,descricao,debito,credito)
    values
      (lanc,c.conta_receita_id,'Estorno de receita - '||d.numero,d.subtotal,0),
      (lanc,c.conta_iva_liquidado_id,'Estorno de IVA - '||d.numero,d.imposto,0),
      (lanc,c.conta_clientes_id,'Crédito ao cliente - '||d.numero,0,d.total);
  else
    insert into public.lancamento_linhas_contabeis(lancamento_id,conta_id,descricao,debito,credito)
    values
      (lanc,c.conta_clientes_id,'Cliente - '||d.cliente_nome||' / '||d.numero,d.total,0),
      (lanc,c.conta_receita_id,'Receita - '||d.numero,0,d.subtotal),
      (lanc,c.conta_iva_liquidado_id,'IVA liquidado - '||d.numero,0,d.imposto);
  end if;

  select coalesce(sum(debito),0),coalesce(sum(credito),0)
  into total_debito,total_credito
  from public.lancamento_linhas_contabeis where lancamento_id=lanc;
  if round(total_debito,2) <> round(total_credito,2) then
    raise exception 'Lançamento desequilibrado: débito=% crédito=%',total_debito,total_credito;
  end if;

  insert into public.contabilizacoes_fiscais(instituicao_id,documento_fiscal_id,lancamento_id,tipo)
  values(d.instituicao_id,d.id,lanc,
         case when d.tipo='nota_credito' then 'nota_credito'
              when d.tipo='nota_debito' then 'nota_debito' else 'venda' end);
  return lanc;
end;
$function$;

commit;

-- Testes obrigatórios antes de qualquer aplicação:
-- 1) instituição A tenta emitir com aluno/documento de origem da instituição B: deve falhar.
-- 2) p_criado_por de outro utilizador: documento deve registar auth.uid(), nunca o valor enviado.
-- 3) vincular recibo como fatura e fatura como recibo: deve falhar.
-- 4) pagamentos nulos/zero/negativos e valor acima do saldo: devem falhar.
-- 5) duas tentativas concorrentes de pagamento que excederiam o saldo: uma deve falhar após bloqueio da cobrança.
-- 6) contabilizar documento anulado: deve falhar; contabilização repetida deve manter idempotência.
-- 7) repetir todos os testes com utilizadores de duas instituições diferentes.
