const assert = require("node:assert/strict");
const fs = require("node:fs");

const pkg = require("../package.json");
assert.equal(pkg.name, "nova-toddle-escolar-desktop");
assert.equal(pkg.version, "1.0.0");
assert.equal(pkg.main, "electron/main.js");
assert.match(pkg.scripts["dist:win"], /electron-builder/);

const html = fs.readFileSync("index.html", "utf8");
assert.match(html, /NOVA_BOOT_SCREEN/);
assert.match(html, /loadSupabaseClient/);
assert.match(html, /setTimeout\(/);
assert.match(html, /Supabase/);
assert.doesNotMatch(html, /throw new Error\("Supabase JS indisponível"\)/);

assert.match(html, /id="sr"/);
for (const role of ["student", "teacher", "parent", "formando"]) {
  assert.match(html, new RegExp('value="' + role + '"'));
}
assert.match(html, /requested_role:requestedRole/);

const registrationMigration = fs.readFileSync("supabase/migrations/202610160002_public_registration_roles.sql", "utf8");
assert.match(registrationMigration, /requested_role::public\.user_role/);
assert.match(registrationMigration, /false\s*\n\s*\)\s*\n\s*on conflict/i);
assert.match(registrationMigration, /trg_auth_user_school_profile/);
assert.match(registrationMigration, /ensure_formando_from_auth/);
assert.match(registrationMigration, /ux_formandos_perfil_id_not_null/);


const workflow = fs.readFileSync(".github/workflows/build-nova-toddle-windows.yml", "utf8");
assert.match(workflow, /nova-toddle-escolar-windows-installer/);
assert.match(workflow, /release\/\*\.exe/);
assert.match(workflow, /npm run check/);

console.log("NOVA TODDLE build smoke test: PASS");
