const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const pkg = require("../package.json");
assert.equal(pkg.name, "nova-toddle-escolar-desktop");
assert.equal(pkg.version, "1.0.0");
assert.equal(pkg.main, "electron/main.js");
assert.match(pkg.scripts["dist:win"], /electron-builder/);

const html = fs.readFileSync("index.html", "utf8");
assert.match(html, /NOVA_BOOT_SCREEN/);
assert.match(html, /loadSupabaseClient/);
assert.match(html, /setTimeout\(function\(\)\{s\.remove\(\);next\(\);\},8000\)/);
assert.match(html, /Supabase JS não pôde ser carregado/);
assert.doesNotMatch(html, /throw new Error\("Supabase JS indisponível"\)/);
assert.match(html, /LICENSE_ENFORCEMENT_ENABLED=false/);
assert.match(html, /license-control/);
assert.match(html, /Licenças e instalações/);
assert.match(html, /Confirmar pagamento verificado/);
assert.match(html, /function financeView/);
assert.match(html, /function accountingView/);
assert.match(html, /function rhView/);
assert.match(html, /function purchasesView/);
assert.match(html, /Contabilidade/);
assert.match(html, /fiscal_emitir_documento/);
assert.match(html, /contabilizar_documento_fiscal/);
const engines = require("../electron/finance-hr-engine.js");
const invoice = engines.calculateDocumentLines([
  { description: "Mensalidade", quantity: 2, unitPrice: 1000, discount: 100, taxRate: 14 },
  { description: "Material", quantity: 1, unitPrice: 500, discount: 0, taxRate: 0 }
]);
assert.equal(invoice.subtotal, 2500);
assert.equal(invoice.discount, 100);
assert.equal(invoice.tax, 266);
assert.equal(invoice.total, 2666);
assert.equal(engines.validateJournal([{ debit: 100, credit: 0 }, { debit: 0, credit: 100 }]).balanced, true);
assert.throws(() => engines.validateJournal([{ debit: 100, credit: 0 }, { debit: 0, credit: 99 }]), /desequilibrado/);
assert.equal(engines.calculatePurchaseLines([{ description: "Cadernos", quantity: 4, unitPrice: 50 }]).total, 200);
assert.throws(() => engines.calculatePayroll({ base: 100000 }, null), /regras salariais fiscais validadas/);
for (const match of html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)) {
  new vm.Script(match[1], { filename: "index-inline-script.js" });
}
const licenseMigration = fs.readFileSync("supabase/migrations/20261028140000_license_installation_control.sql", "utf8");
assert.match(licenseMigration, /plataforma_instalacoes/);
assert.match(licenseMigration, /ENABLE ROW LEVEL SECURITY/i);
const licenseFunction = fs.readFileSync("supabase/functions/license-control/index.ts", "utf8");
assert.match(licenseFunction, /confirm_payment/);
assert.match(licenseFunction, /profile.role !== "super_admin"/);
assert.match(licenseFunction, /plataforma_licenca_eventos/);


const workflow = fs.readFileSync(".github/workflows/build-nova-toddle-windows.yml", "utf8");
assert.match(workflow, /nova-toddle-escolar-windows-installer/);
assert.match(workflow, /release\/\*\.exe/);
assert.match(workflow, /npm run check/);

console.log("NOVA TODDLE build smoke test: PASS");
