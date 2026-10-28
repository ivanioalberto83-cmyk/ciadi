-- PROPOSTA DE CORREÇÃO — não aplicar automaticamente em produção.
-- Rever em ambiente de homologação com backup, testes de regressão e aprovação fiscal.
-- Reforça o vínculo institucional do aluno/documento de origem e a autoria auditável.

CREATE OR REPLACE FUNCTION public.fiscal_emitir_documento(
  p_instituicao_id uuid,
  p_serie_id uuid,
  p_tipo text,
  p_cliente_nome text,
  p_cliente_nif text DEFAULT NULL::text,
  p_cliente_email text DEFAULT NULL::text,
  p_cliente_telefone text DEFAULT NULL::text,
  p_aluno_id uuid DEFAULT NULL::uuid,
  p_data_emissao date DEFAULT CURRENT_DATE,
  p_data_vencimento date DEFAULT NULL::date,
  p_linhas jsonb DEFAULT '[]'::jsonb,
  p_criado_por uuid DEFAULT NULL::uuid,
  p_documento_origem_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_doc_id uuid;
  v_numero text;
  v_hash text;
  v_payload text;
  v_linha jsonb;
  v_serie public.series_fiscais%rowtype;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.perfis p
    WHERE p.id = auth.uid()
      AND p.role IN ('super_admin','school_admin','accountant','principal','reception')
      AND (p.role = 'super_admin' OR p.instituicao_id = p_instituicao_id)
  ) THEN
    RAISE EXCEPTION 'Sem autorização para emitir documentos desta instituição';
  END IF;

  -- O utilizador autenticado deve ser a origem da autoria registada.
  IF p_criado_por IS NOT NULL AND p_criado_por <> auth.uid() THEN
    RAISE EXCEPTION 'O utilizador de criação deve corresponder à sessão autenticada';
  END IF;

  IF p_tipo IS NULL OR p_tipo NOT IN ('fatura','fatura_recibo','recibo','nota_credito','nota_debito','proforma') THEN
    RAISE EXCEPTION 'Tipo de documento fiscal inválido: %', p_tipo;
  END IF;
  IF COALESCE(trim(p_cliente_nome),'') = '' THEN
    RAISE EXCEPTION 'Nome do cliente é obrigatório';
  END IF;
  IF jsonb_typeof(COALESCE(p_linhas,'[]'::jsonb)) <> 'array'
     OR jsonb_array_length(COALESCE(p_linhas,'[]'::jsonb)) = 0 THEN
    RAISE EXCEPTION 'O documento deve possuir pelo menos uma linha';
  END IF;

  -- Não permitir associar aluno de outra instituição ao documento fiscal.
  IF p_aluno_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.alunos a
    WHERE a.id = p_aluno_id
      AND a.instituicao_id = p_instituicao_id
  ) THEN
    RAISE EXCEPTION 'Aluno inexistente ou pertencente a outra instituição';
  END IF;

  -- O documento de origem, quando fornecido, deve pertencer à mesma instituição.
  IF p_documento_origem_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.documentos_fiscais d
    WHERE d.id = p_documento_origem_id
      AND d.instituicao_id = p_instituicao_id
  ) THEN
    RAISE EXCEPTION 'Documento de origem inexistente ou pertencente a outra instituição';
  END IF;

  SELECT * INTO v_serie
  FROM public.series_fiscais
  WHERE id = p_serie_id
    AND instituicao_id = p_instituicao_id
    AND ativa = true
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Série fiscal inexistente, inativa ou pertencente a outra instituição';
  END IF;
  IF v_serie.tipo_documento <> p_tipo THEN
    RAISE EXCEPTION 'A série fiscal não corresponde ao tipo do documento';
  END IF;
  IF v_serie.exercicio <> extract(year FROM p_data_emissao)::int THEN
    RAISE EXCEPTION 'A série fiscal não corresponde ao exercício da emissão';
  END IF;

  v_numero := public.fiscal_proximo_numero(p_serie_id);

  INSERT INTO public.documentos_fiscais (
    instituicao_id, serie_id, aluno_id, tipo, numero, data_emissao, data_vencimento,
    cliente_nome, cliente_nif, cliente_email, cliente_telefone, estado, criado_por, documento_origem_id
  ) VALUES (
    p_instituicao_id, p_serie_id, p_aluno_id, p_tipo, v_numero, p_data_emissao, p_data_vencimento,
    trim(p_cliente_nome), nullif(trim(p_cliente_nif),''), nullif(trim(p_cliente_email),''),
    nullif(trim(p_cliente_telefone),''), 'rascunho', auth.uid(), p_documento_origem_id
  ) RETURNING id INTO v_doc_id;

  FOR v_linha IN SELECT * FROM jsonb_array_elements(p_linhas) LOOP
    INSERT INTO public.documentos_fiscais_linhas (
      documento_id, descricao, quantidade, preco_unitario, desconto, taxa_imposto, unidade, codigo_item
    ) VALUES (
      v_doc_id,
      coalesce(v_linha->>'descricao',''),
      coalesce((v_linha->>'quantidade')::numeric,1),
      coalesce((v_linha->>'preco_unitario')::numeric,0),
      coalesce((v_linha->>'desconto')::numeric,0),
      coalesce((v_linha->>'taxa_imposto')::numeric,0),
      coalesce(v_linha->>'unidade','UN'),
      nullif(v_linha->>'codigo_item','')
    );
  END LOOP;

  PERFORM public.fiscal_calcular_documento(v_doc_id);

  SELECT jsonb_build_object(
    'id',d.id,'instituicao_id',d.instituicao_id,'serie_id',d.serie_id,'tipo',d.tipo,
    'numero',d.numero,'data_emissao',d.data_emissao,'cliente_nome',d.cliente_nome,
    'cliente_nif',d.cliente_nif,'subtotal',d.subtotal,'desconto',d.desconto,
    'imposto',d.imposto,'total',d.total
  )::text INTO v_payload
  FROM public.documentos_fiscais d
  WHERE d.id = v_doc_id;

  v_hash := encode(digest(v_payload,'sha256'),'hex');

  UPDATE public.documentos_fiscais
  SET estado='emitido', emitido_em=now(), hash_fiscal=v_hash, hash_algoritmo='SHA-256'
  WHERE id = v_doc_id;

  INSERT INTO public.fiscal_auditoria(instituicao_id,documento_fiscal_id,operacao,utilizador_id,dados)
  VALUES(p_instituicao_id,v_doc_id,'EMISSAO',auth.uid(),
         jsonb_build_object('numero',v_numero,'hash_fiscal',v_hash));

  RETURN v_doc_id;
END;
$function$;

-- A migração é apenas proposta: validar em ambiente isolado antes de aplicar.
