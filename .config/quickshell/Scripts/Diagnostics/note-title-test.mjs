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
    assert.equal(options.headers.Authorization, "Bearer private-test-key");
    assert.equal(options.method, "POST");
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    let response, status;
    if (url === "https://openrouter.ai/api/v1/chat/completions") {
        assert.equal(body.model, process.env.EXPECT_MODEL);
        assert.equal(body.messages[1].content, process.env.EXPECT_CONTENT.slice(0, 12000));
        assert.equal(body.max_tokens, 80);
        assert.deepEqual(body.reasoning, { enabled: false });
        response = {choices: [{message: {content: process.env.TITLE}}]};
        status = process.env.TITLE_STATUS;
    } else {
        assert.equal(url, "https://openrouter.ai/api/alpha/decisions");
        assert.equal(body.model, "typesafe/jev-1.14");
        assert.equal(body.state.note, process.env.EXPECT_CONTENT.slice(0, 12000));
        const probabilities = JSON.parse(process.env.PROBABILITIES);
        const answers = Object.fromEntries(Object.entries(body.questions).map(([tag, question]) => {
            assert.equal(question.type, "noul");
            assert.equal(typeof question.criteria.true, "string");
            assert.equal(typeof question.criteria.false, "string");
            return [tag, {type: "noul", noul: probabilities[tag] ?? 0.05}];
        }));
        if (process.env.DECISIONS === "missing") delete answers.ai;
        if (process.env.DECISIONS === "wrong-type") answers.ai.type = "choice";
        if (process.env.DECISIONS === "extra") answers["not-an-allowed-tag"] = {type: "noul", noul: 1};
        response = {answers};
        status = process.env.TAG_STATUS;
    }
    if (process.env.SCENARIO === "network") throw new Error("private-test-key private-note-text");
    return new Response(process.env.SCENARIO === "malformed" ? "private-note-text" : JSON.stringify(response), {status: Number(status)});
};
process.on("exit", () => assert.equal(calls, Number(process.env.EXPECT_CALLS)));
`);

let checks = 0;
function run({ settings = { apiKey: "private-test-key" }, input = "Note body: $(touch /must-not-run) `literal`", title = "LinkedIn video export settings", titleStatus = 200, tagStatus = 200, scenario = "ok", decisions = "ok", probabilities = { ai: 0.95, programming: 0.9 }, tagsOnly = false, calls = tagsOnly ? 1 : 2 } = {}) {
    checks++;
    rmSync(configPath, { force: true });
    if (settings !== null) writeFileSync(configPath, typeof settings === "string" ? settings : JSON.stringify(settings));
    const result = spawnSync(process.execPath, ["--import", mock, helper, ...(tagsOnly ? ["--tags"] : [])], {
        input, encoding: "utf8", timeout: 5000,
        env: { ...process.env, XDG_CONFIG_HOME: directory, TITLE: title, TITLE_STATUS: String(titleStatus), TAG_STATUS: String(tagStatus),
            SCENARIO: scenario, DECISIONS: decisions, PROBABILITIES: JSON.stringify(probabilities), EXPECT_CALLS: String(calls),
            EXPECT_MODEL: settings?.model || "google/gemini-2.5-flash-lite", EXPECT_CONTENT: input.trim() },
    });
    assert.ifError(result.error);
    assert.ok(!result.stderr.includes("private-test-key") && !result.stderr.includes("private-note-text"), "secrets must not appear in errors");
    return result;
}
const metadata = options => {
    const result = run(options);
    assert.equal(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
};

try {
    for (const settings of [null, {}, { apiKey: "" }, { apiKey: "   " }]) {
        const result = run({ settings, calls: 0 });
        assert.equal(result.status, 0);
        assert.equal(result.stdout, "");
    }
    assert.equal(run({ input: "  \n ", calls: 0 }).status, 0);
    assert.deepEqual(metadata({ title: '“LinkedIn\n video export settings”' }), { title: "LinkedIn video export settings", tags: ["ai", "programming"] });
    assert.equal(metadata({ settings: { apiKey: "private-test-key", model: "deepseek/deepseek-v4.1-flash-1017" } }).title, "LinkedIn video export settings");
    assert.equal(metadata({ input: "a".repeat(15000) }).tags.length, 2);
    assert.equal(metadata({ title: "a".repeat(120) }).title.length, 80);
    assert.deepEqual(metadata({ tagsOnly: true }), { tags: ["ai", "programming"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { start_up: 0.96 } }), { tags: ["start_up"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { ai: 0.95, zig: 0.8, programming: 0.85, cryptography: 0.9 } }), { tags: ["ai", "cryptography", "programming"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { ai: 0.79 } }), { tags: [] });
    assert.deepEqual(metadata({ tagsOnly: true, decisions: "extra" }), { tags: ["ai", "programming"] });
    for (const options of [{ decisions: "missing" }, { decisions: "wrong-type" }, { probabilities: { ai: 1.1 } }, { probabilities: { ai: "0.95" } }, { tagStatus: 503 }])
        assert.deepEqual(metadata(options), { title: "LinkedIn video export settings" });
    for (const options of [{ titleStatus: 503 }, { title: " " }])
        assert.deepEqual(metadata(options), { tags: ["ai", "programming"] });
    for (const options of [{ titleStatus: 401, tagStatus: 401 }, { tagsOnly: true, tagStatus: 429 }, { scenario: "network" }, { scenario: "malformed" }, { settings: "private-test-key invalid JSON", calls: 0 }]) {
        const result = run(options);
        assert.equal(result.status, 1);
        assert.equal(result.stdout, "");
    }
    console.log(`PASS: ${checks} note metadata checks (title/tag requests, partial failures, bounded tags and secret handling)`);
} finally {
    rmSync(directory, { recursive: true, force: true });
}
