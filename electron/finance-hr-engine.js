(function (root) {
  "use strict";
  const round2 = value => Math.round((Number(value) + Number.EPSILON) * 100) / 100;
  const number = (value, label) => {
    const n = Number(value);
    if (!Number.isFinite(n)) throw new Error(label + " deve ser numérico.");
    return n;
  };

  function calculateDocumentLines(lines) {
    if (!Array.isArray(lines) || lines.length === 0) throw new Error("Adicione pelo menos uma linha ao documento.");
    const normalized = lines.map((line, index) => {
      const label = "Linha " + (index + 1);
      const description = String(line.description || "").trim();
      const quantity = number(line.quantity, label + ": quantidade");
      const unitPrice = number(line.unitPrice, label + ": preço unitário");
      const discount = number(line.discount ?? 0, label + ": desconto");
      const taxRate = number(line.taxRate, label + ": taxa de imposto");
      if (!description) throw new Error(label + ": descrição obrigatória.");
      if (quantity <= 0) throw new Error(label + ": quantidade deve ser superior a zero.");
      if (unitPrice < 0 || discount < 0) throw new Error(label + ": preço e desconto não podem ser negativos.");
      if (taxRate < 0 || taxRate > 100) throw new Error(label + ": taxa de imposto fora do intervalo permitido.");
      const gross = round2(quantity * unitPrice);
      if (discount > gross) throw new Error(label + ": desconto superior ao valor bruto.");
      const taxable = round2(gross - discount);
      const tax = round2(taxable * taxRate / 100);
      return { description, quantity, unitPrice, discount, taxRate, gross, taxable, tax, total: round2(taxable + tax) };
    });
    const subtotal = round2(normalized.reduce((sum, line) => sum + line.gross, 0));
    const discount = round2(normalized.reduce((sum, line) => sum + line.discount, 0));
    const tax = round2(normalized.reduce((sum, line) => sum + line.tax, 0));
    return { lines: normalized, subtotal, discount, taxable: round2(subtotal - discount), tax, total: round2(subtotal - discount + tax) };
  }

  function validateFiscalSeries(series, type, date, institutionId) {
    if (!series) throw new Error("Selecione uma série fiscal ativa.");
    if (series.instituicao_id !== institutionId) throw new Error("A série fiscal não pertence à instituição autenticada.");
    if (series.ativa !== true) throw new Error("A série fiscal está inativa.");
    if (series.tipo_documento !== type) throw new Error("A série selecionada não corresponde ao tipo de documento.");
    const year = new Date(date + "T00:00:00").getFullYear();
    if (Number(series.exercicio) !== year) throw new Error("A série fiscal não corresponde ao ano da emissão.");
    if (!String(series.codigo_agt || "").trim() || !String(series.estado_agt || "").trim() || Number(series.quantidade_autorizada || 0) <= 0) {
      throw new Error("Emissão bloqueada: falta confirmar o código, o estado de autorização e a quantidade autorizada da série junto da AGT.");
    }
    const status = String(series.estado_agt).trim().toLowerCase();
    if (!["autorizada", "autorizado", "ativa", "ativo", "aprovada", "aprovado", "validada", "validado"].includes(status)) {
      throw new Error("Emissão bloqueada: o estado AGT da série não está reconhecido como autorizado. Confirme-o com a AGT.");
    }
    if (Number(series.proximo_numero || 0) > Number(series.quantidade_autorizada)) {
      throw new Error("Emissão bloqueada: a série atingiu a quantidade autorizada.");
    }
    return true;
  }

  function calculatePayroll(input, rules) {
    if (!rules || !rules.source || !rules.effectiveFrom || !Array.isArray(rules.irtBrackets) || rules.irtBrackets.length === 0) {
      throw new Error("Não existem regras salariais fiscais validadas. Configure a fonte oficial, a vigência, as taxas INSS e os escalões IRT antes de calcular a folha.");
    }
    const employeeRate = number(rules.inssEmployeeRate, "Taxa INSS do trabalhador");
    const employerRate = number(rules.inssEmployerRate, "Taxa INSS da entidade empregadora");
    if (employeeRate < 0 || employeeRate > 1 || employerRate < 0 || employerRate > 1) throw new Error("As taxas INSS devem ser configuradas como proporções entre 0 e 1.");
    const base = number(input.base, "Salário base");
    const allowances = number(input.allowances ?? 0, "Subsídios");
    const bonuses = number(input.bonuses ?? 0, "Prémios");
    const otherDeductions = number(input.otherDeductions ?? 0, "Outros descontos");
    if (base < 0 || allowances < 0 || bonuses < 0 || otherDeductions < 0) throw new Error("Os valores salariais não podem ser negativos.");
    const gross = round2(base + allowances + bonuses);
    const inssEmployee = round2(gross * employeeRate);
    const inssEmployer = round2(gross * employerRate);
    const irtBase = rules.irtBaseMode === "after_inss" ? Math.max(0, round2(gross - inssEmployee)) : gross;
    const sorted = rules.irtBrackets.slice().sort((a, b) => (a.upTo == null ? Infinity : Number(a.upTo)) - (b.upTo == null ? Infinity : Number(b.upTo)));
    const bracket = sorted.find(b => b.upTo == null || irtBase <= Number(b.upTo));
    if (!bracket) throw new Error("A tabela IRT não cobre a base tributável calculada.");
    const irtRate = number(bracket.rate, "Taxa do escalão IRT");
    const irtDeduction = number(bracket.deduction ?? 0, "Parcela a abater IRT");
    if (irtRate < 0 || irtRate > 1 || irtDeduction < 0) throw new Error("Escalão IRT inválido.");
    const irt = Math.max(0, round2(irtBase * irtRate - irtDeduction));
    const net = round2(gross - inssEmployee - irt - otherDeductions);
    if (net < 0) throw new Error("Os descontos excedem o salário bruto.");
    return { gross, inssEmployee, inssEmployer, irtBase, irt, otherDeductions: round2(otherDeductions), net, employerCost: round2(gross + inssEmployer), rulesSource: rules.source, rulesEffectiveFrom: rules.effectiveFrom };
  }

  function validateJournal(lines) {
    if (!Array.isArray(lines) || lines.length < 2) throw new Error("O lançamento deve conter pelo menos duas linhas.");
    let debit = 0, credit = 0;
    for (const [i, line] of lines.entries()) {
      const d = number(line.debit ?? 0, "Débito da linha " + (i + 1));
      const c = number(line.credit ?? 0, "Crédito da linha " + (i + 1));
      if (d < 0 || c < 0 || (d > 0 && c > 0)) throw new Error("Cada linha deve ter débito ou crédito, nunca ambos nem valores negativos.");
      debit += d; credit += c;
    }
    debit = round2(debit); credit = round2(credit);
    if (debit <= 0 || Math.abs(debit - credit) > 0.01) throw new Error("Lançamento desequilibrado: débito " + debit.toFixed(2) + " / crédito " + credit.toFixed(2) + ".");
    return { debit, credit, balanced: true };
  }

  function calculatePurchaseLines(lines) {
    if (!Array.isArray(lines) || lines.length === 0) throw new Error("Adicione pelo menos um artigo ao pedido.");
    const result = lines.map((line, i) => {
      const quantity = number(line.quantity, "Quantidade do artigo " + (i + 1));
      const unitPrice = number(line.unitPrice, "Preço do artigo " + (i + 1));
      if (!String(line.description || "").trim()) throw new Error("A descrição do artigo " + (i + 1) + " é obrigatória.");
      if (quantity <= 0 || unitPrice < 0) throw new Error("Quantidade ou preço inválido no artigo " + (i + 1) + ".");
      return { description: String(line.description).trim(), quantity, unitPrice, total: round2(quantity * unitPrice) };
    });
    return { lines: result, total: round2(result.reduce((sum, line) => sum + line.total, 0)) };
  }

  const api = Object.freeze({ calculateDocumentLines, validateFiscalSeries, calculatePayroll, validateJournal, calculatePurchaseLines });
  root.NOVAToddleEngines = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);
