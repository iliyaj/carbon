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
const redirectMock = join(directory, "redirect.mjs");
mkdirSync(join(directory, "carbon"));
writeFileSync(mock, `
import assert from "node:assert/strict";
let calls = 0;
globalThis.fetch = async (url, options) => {
    calls++;
    assert.equal(options.headers.Authorization, "Bearer private-test-key");
    assert.equal(options.method, "POST");
    assert.equal(options.redirect, "error");
    assert.ok(options.signal instanceof AbortSignal);
    const body = JSON.parse(options.body);
    assert.deepEqual(body.provider, { data_collection: "deny", zdr: true });
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
    if (process.env.SCENARIO === "oversized" || process.env.SCENARIO === "oversized-title" && url.endsWith("completions"))
        response.padding = "私".repeat(22000);
    const encoded = new TextEncoder().encode(process.env.SCENARIO === "malformed" ? "private-note-text" : JSON.stringify(response));
    let offset = 0;
    const stream = new ReadableStream({
        pull(controller) {
            if (offset === encoded.length) return controller.close();
            controller.enqueue(encoded.slice(offset, offset + 4096));
            offset = Math.min(offset + 4096, encoded.length);
        },
    });
    return new Response(stream, {status: Number(status)});
};
process.on("exit", () => assert.equal(calls, Number(process.env.EXPECT_CALLS)));
`);
writeFileSync(redirectMock, `
import assert from "node:assert/strict";
import { createServer } from "node:http";
let requests = 0, redirected = 0;
const server = createServer((request, response) => {
    if (request.url === "/sink") {
        redirected++;
        response.writeHead(200).end("{}");
    } else {
        requests++;
        response.writeHead(307, { Location: "/sink" }).end();
    }
});
await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
server.unref();
const nativeFetch = globalThis.fetch;
globalThis.fetch = (url, options) => nativeFetch("http://127.0.0.1:" + server.address().port + new URL(url).pathname, options);
process.on("exit", () => {
    assert.equal(requests, 2);
    assert.equal(redirected, 0, "note data must never follow a redirect");
});
`);

let checks = 0;
function run({ settings = { apiKey: "private-test-key" }, mode = 0o600, configType = "file", input = "Note body: $(touch /must-not-run) `literal`", title = "LinkedIn video export settings", titleStatus = 200, tagStatus = 200, scenario = "ok", decisions = "ok", probabilities = { ai: 0.95, programming: 0.9 }, tagsOnly = false, calls = tagsOnly ? 1 : 2 } = {}) {
    checks++;
    rmSync(configPath, { recursive: true, force: true });
    if (configType === "directory") mkdirSync(configPath, { mode });
    else if (configType === "fifo") assert.equal(spawnSync("mkfifo", ["-m", "600", configPath]).status, 0);
    else if (settings !== null) writeFileSync(configPath, typeof settings === "string" ? settings : JSON.stringify(settings), { mode });
    const result = spawnSync(process.execPath, ["--import", scenario === "redirect" ? redirectMock : mock, helper, ...(tagsOnly ? ["--tags"] : [])], {
        input, encoding: "utf8", timeout: 5000,
        env: { ...process.env, XDG_CONFIG_HOME: directory, TITLE: title, TITLE_STATUS: String(titleStatus), TAG_STATUS: String(tagStatus),
            SCENARIO: scenario, DECISIONS: decisions, PROBABILITIES: JSON.stringify(probabilities), EXPECT_CALLS: String(calls),
            EXPECT_MODEL: settings?.model || "google/gemini-2.5-flash-lite", EXPECT_CONTENT: input.trim() },
    });
    assert.ifError(result.error);
    assert.doesNotMatch(result.stderr, /AssertionError/, "request mock contract failed");
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
    assert.equal(metadata({ mode: 0o400 }).title, "LinkedIn video export settings");
    assert.deepEqual(metadata({ tagsOnly: true }), { tags: ["ai", "programming"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { start_up: 0.96 } }), { tags: ["start_up"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { ai: 0.95, zig: 0.8, programming: 0.85, cryptography: 0.9 } }), { tags: ["ai", "cryptography", "programming"] });
    assert.deepEqual(metadata({ tagsOnly: true, probabilities: { ai: 0.79 } }), { tags: [] });
    assert.deepEqual(metadata({ tagsOnly: true, decisions: "extra" }), { tags: ["ai", "programming"] });
    for (const options of [{ decisions: "missing" }, { decisions: "wrong-type" }, { probabilities: { ai: 1.1 } }, { probabilities: { ai: "0.95" } }, { tagStatus: 503 }])
        assert.deepEqual(metadata(options), { title: "LinkedIn video export settings" });
    for (const options of [{ titleStatus: 503 }, { title: " " }, { scenario: "oversized-title" }])
        assert.deepEqual(metadata(options), { tags: ["ai", "programming"] });
    for (const options of [{ titleStatus: 401, tagStatus: 401 }, { tagsOnly: true, tagStatus: 429 }, { scenario: "network" }, { scenario: "redirect" }, { scenario: "malformed" }, { scenario: "oversized" }, { settings: "private-test-key invalid JSON", calls: 0 },
        ...[0o644, 0o640, 0o660, 0o604].map(mode => ({ mode, calls: 0 })),
        ...["directory", "fifo"].map(configType => ({ configType, calls: 0 }))]) {
        const result = run(options);
        assert.equal(result.status, 1);
        assert.equal(result.stdout, "");
    }
    console.log(`PASS: ${checks} note metadata checks (title/tag requests, partial failures, bounded tags and secret handling)`);
} finally {
    rmSync(directory, { recursive: true, force: true });
}
