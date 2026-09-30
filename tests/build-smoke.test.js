const assert = require("node:assert/strict");
const fs = require("node:fs");

const pkg = require("../package.json");
assert.equal(pkg.name, "nova-toddle-escolar-desktop");
assert.equal(pkg.version, "1.0.0");
assert.equal(pkg.main, "electron/main.js");
assert.match(pkg.scripts["dist:win"], /electron-builder/);

const workflow = fs.readFileSync(".github/workflows/build-nova-toddle-windows.yml", "utf8");
assert.match(workflow, /nova-toddle-escolar-windows-installer/);
assert.match(workflow, /release\/\*\.exe/);
assert.match(workflow, /npm run check/);

console.log("NOVA TODDLE build smoke test: PASS");
