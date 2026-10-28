const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const pkg = require("../package.json");
assert.equal(pkg.name, "nova-toddle-escolar-desktop");
assert.equal(pkg.version, "1.0.0");
assert.equal(pkg.main, "electron/main.js");
assert.match(pkg.scripts["dist:win"], /electron-builder/);

const html = fs.readFileSync("index.html", "utf8");
assert.match(html, /__NOVA_BOOT_SCREEN/);
assert.match(html, /loadSupabaseClient/);
assert.match(html, /https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2/);
assert.match(html, /https:\/\/unpkg\.com\/@supabase\/supabase-js@2/);
// Verify the actual retry timeout and cleanup behavior, not a brittle
// single-line expression that assumes the word "Supabase" is nearby.
assert.match(html, /var\s+timer\s*=\s*setTimeout\s*\(/);
assert.match(html, /setTimeout\s*\(function\s*\(\)\s*\{\s*s\.remove\(\)\s*;\s*next\(\)\s*;\s*\}\s*,\s*8000\s*\)/);
assert.match(html, /s\.onload\s*=\s*function\s*\(\)\s*\{\s*clearTimeout\(timer\)/);
assert.match(html, /s\.onerror\s*=\s*function\s*\(\)\s*\{\s*clearTimeout\(timer\)/);
assert.match(html, /nova:supabase-ready/);
assert.match(html, /__NOVA_BOOT_ERROR__/);
assert.match(html, /resetPasswordForEmail/);
assert.match(html, /id="forgotPassword"/);
assert.match(html, /redirectTo:\s*window\.location\.origin\+window\.location\.pathname/);
assert.match(html, /Se existir uma conta associada a este email/);
assert.doesNotMatch(html, /throw new Error\("Supabase JS indisponível"\)/);

// Parse every inline JavaScript block without executing browser code.
const inlineScripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1])
  .filter((script) => script.trim().length > 0);
assert.ok(inlineScripts.length >= 2, "Expected boot and application inline scripts");
inlineScripts.forEach((script, index) => {
  assert.doesNotThrow(() => new vm.Script(script, { filename: `index-inline-${index + 1}.js` }));
});

const main = fs.readFileSync("electron/main.js", "utf8");
assert.match(main, /contextIsolation:\s*true/);
assert.match(main, /nodeIntegration:\s*false/);
assert.match(main, /sandbox:\s*true/);

const workflow = fs.readFileSync(".github/workflows/build-nova-toddle-windows.yml", "utf8");
assert.match(workflow, /nova-toddle-escolar-windows-installer/);
assert.match(workflow, /release\/\*\.exe/);
assert.match(workflow, /npm run check/);
assert.match(workflow, /npm test/);

console.log("NOVA TODDLE build smoke test: PASS");
