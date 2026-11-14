#!/usr/bin/env node

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const directory = mkdtempSync(join(tmpdir(), "carbon-note-title-"));
const configPath = join(directory, "carbon", "openrouter.json");
const helper = fileURLToPath(new URL("../note-title.mts", import.meta.url));
const mock = join(directory, "mock.mjs");
mkdirSync(join(directory, "carbon"));
writeFileSync(mock, `
import assert from "node:assert/strict";
let calls = 0;
globalThis.fetch = async (url, options) => {
    calls++;
    assert.equal(url, "https://openrouter.ai/api/v1/chat/completions");
    assert.equal(options.headers.Authorization, "Bearer private-test-key");
    assert.equal(options.method, "POST");
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    assert.equal(body.model, process.env.EXPECT_MODEL);
    assert.equal(body.messages[1].content, process.env.EXPECT_CONTENT.slice(0, 12000));
    assert.equal(body.max_tokens, 80);
    assert.deepEqual(body.reasoning, { enabled: false });
    if (process.env.SCENARIO === "network") throw new Error("private-test-key private-note-text");
    return new Response(process.env.SCENARIO === "malformed" ? "private-note-text" : JSON.stringify({
        choices: [{message: {content: process.env.TITLE}}],
        error: "private-test-key private-note-text",
    }), {status: Number(process.env.HTTP_STATUS || 200)});
};
process.on("exit", () => assert.equal(calls, Number(process.env.EXPECT_CALLS)));
`);

function run({ settings = { apiKey: "private-test-key" }, input = "Note body: $(touch /must-not-run) `literal`", title = "LinkedIn video export settings", status = 200, scenario = "ok", calls = 1 } = {}) {
    rmSync(configPath, { force: true });
    if (settings !== null) writeFileSync(configPath, typeof settings === "string" ? settings : JSON.stringify(settings));
    const result = spawnSync(process.execPath, ["--import", mock, helper], {
        input, encoding: "utf8", timeout: 5000,
        env: { ...process.env, XDG_CONFIG_HOME: directory, TITLE: title, HTTP_STATUS: String(status), SCENARIO: scenario,
            EXPECT_CALLS: String(calls), EXPECT_MODEL: settings?.model || "google/gemini-2.5-flash-lite", EXPECT_CONTENT: input.trim() },
    });
    assert.ifError(result.error);
    assert.ok(!result.stderr.includes("private-test-key") && !result.stderr.includes("private-note-text"), "secrets must not appear in errors");
    return result;
}

try {
    for (const settings of [null, {}, { apiKey: "" }, { apiKey: "   " }]) {
        const result = run({ settings, calls: 0 });
        assert.equal(result.status, 0);
        assert.equal(result.stdout, "");
    }
    assert.equal(run({ input: "  \n ", calls: 0 }).status, 0);
    const valid = run({ title: '“LinkedIn\n video export settings”' });
    assert.equal(valid.status, 0);
    assert.deepEqual(JSON.parse(valid.stdout), { title: "LinkedIn video export settings" });
    assert.equal(run({ settings: { apiKey: "private-test-key", model: "deepseek/deepseek-v4.1-flash-1017" } }).status, 0);
    assert.equal(run({ input: "a".repeat(15000) }).status, 0);
    assert.equal(JSON.parse(run({ title: "a".repeat(120) }).stdout).title.length, 80);
    for (const options of [{ status: 401 }, { status: 429 }, { scenario: "network" }, { scenario: "malformed" }, { title: " " }, { settings: "private-test-key invalid JSON", calls: 0 }]) {
        const result = run(options);
        assert.equal(result.status, 1);
        assert.equal(result.stdout, "");
    }
    console.log("PASS: 15 note-title checks (requests, configuration, input limits, errors and secret handling)");
} finally {
    rmSync(directory, { recursive: true, force: true });
}
