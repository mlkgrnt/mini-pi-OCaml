// End-to-end check of the *actual* TypeScript TUI client against the OCaml
// backend. This is the real integration boundary: it imports the compiled
// tui/dist/rpc_client.js, lets it spawn the backend exactly as the TUI does,
// and drives the protocol headlessly (no terminal required).
//
//   cd tui && npx tsc          # produce dist/
//   node test/tui_client_check.mjs <path-to-main.exe>

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const backend = process.argv[2];
if (!backend) {
    console.error("usage: node tui_client_check.mjs <path-to-main.exe>");
    process.exit(2);
}

const clientModule = "../tui/dist/rpc_client.js";
if (!fs.existsSync(new URL(clientModule, import.meta.url))) {
    console.error(`missing ${clientModule} - run 'npx tsc' in tui/ first`);
    process.exit(2);
}

const home = fs.mkdtempSync(path.join(os.tmpdir(), "minipi-tui-home-"));
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "minipi-tui-ws-"));

// Resolve to an absolute path *before* chdir below: the client spawns this
// program after we have moved into a temporary workspace, where a relative
// path would no longer resolve and the spawn would fail with ENOENT.
process.env.MINI_PI_BIN = path.resolve(backend);
process.env.HOME = home;
process.env.USERPROFILE = home;
process.env.FIREWORKS_API_KEY = "";
process.env.MODEL = "";
// Remember where we started: the cleanup below has to step out of the
// workspace before it can delete it (see the finally block).
const rootDir = process.cwd();
process.chdir(workspace);

let failures = 0;
const check = (name, cond, extra = "") => {
    if (cond) console.log(`  ok    ${name}`);
    else {
        failures++;
        console.log(`  FAIL  ${name}${extra ? `\n        ${extra}` : ""}`);
    }
};

const { RpcClient } = await import(clientModule);

const client = new RpcClient();
const events = [];
client.onEvent((e) => events.push(e));

const waitFor = (predicate, ms = 10000) =>
    new Promise((resolve) => {
        const started = Date.now();
        const tick = () => {
            if (predicate()) return resolve(true);
            if (Date.now() - started > ms) return resolve(false);
            setTimeout(tick, 25);
        };
        tick();
    });

try {
    console.log("TypeScript TUI client -> OCaml backend\n");

    const state = await client.getState();
    check("the TUI client resolved a backend and reached it", !!state);
    check("getState returns a model name", typeof state?.model === "string" && state.model.length > 0,
        JSON.stringify(state));

    const created = await client.newSession();
    check("newSession returns a session id", typeof created?.session_id === "string" && created.session_id.length > 0,
        JSON.stringify(created));

    const cmds = await client.getExtensionCommands();
    check("extension commands are visible to the TUI",
        (cmds?.commands ?? []).some((c) => c.name === "permission"), JSON.stringify(cmds));

    const sessions = await client.listSessions();
    check("listSessions returns rows", Array.isArray(sessions?.rows), JSON.stringify(sessions));

    const targets = await client.getRewindTargets();
    check("getRewindTargets returns targets", Array.isArray(targets?.targets), JSON.stringify(targets));

    const before = events.length;
    await client.prompt("say hi");
    const ended = await waitFor(() => events.slice(before).some((e) => e.type === "agent_end"));
    check("prompt produces a complete event stream", ended,
        events.slice(before).map((e) => e.type).join(" -> "));

    const seq = events.slice(before).map((e) => e.type);
    check("events arrive in the order the TUI renders them",
        seq[0] === "agent_start" && seq[seq.length - 1] === "agent_end" && seq.includes("turn_start"),
        seq.join(" -> "));

    const assistant = events.slice(before).find(
        (e) => e.type === "message_end" && e.message?.role === "assistant");
    check("an assistant message is delivered with a stop_reason", !!assistant?.message?.stop_reason,
        JSON.stringify(assistant));

    await client.abort();
    check("abort is accepted while idle", true);
} catch (e) {
    failures++;
    console.log(`  FAIL  harness error: ${e?.message ?? e}`);
} finally {
    try { client.kill(); } catch {}

    // Two things keep the workspace alive on Windows: this process did
    // process.chdir(workspace) earlier, and the backend child was spawned with
    // it as its cwd. Windows refuses to remove a directory that is any
    // process's cwd, so step out first, then retry while the (already killed)
    // child's handle drains. rmSync's own maxRetries all happen inside a single
    // call and are far too quick to cover that, hence the real pause. Cleanup
    // trouble must never mask the actual result, so it notes instead of throws.
    try { process.chdir(rootDir); } catch {}
    const rmTemp = (dir) => {
        const nap = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
        for (let attempt = 0; ; attempt++) {
            try {
                fs.rmSync(dir, { recursive: true, force: true, maxRetries: 3, retryDelay: 50 });
                return;
            } catch (e) {
                if (attempt >= 25) {
                    console.log(`  (note: could not remove ${dir}: ${e.code})`);
                    return;
                }
                nap(200);
            }
        }
    };
    rmTemp(home);
    rmTemp(workspace);
    console.log(`\n${failures === 0 ? "ALL CHECKS PASSED" : "FAILURES PRESENT"} (${failures} failure${failures === 1 ? "" : "s"})`);
    process.exit(failures === 0 ? 0 : 1);
}
