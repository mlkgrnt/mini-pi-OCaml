// Protocol conformance check: drives the OCaml backend over stdin/stdout the
// same way the TypeScript TUI does, and asserts on the exact wire messages.
//
//   node test/rpc_smoke.mjs <path-to-main.exe>
//
// Runs entirely offline: the only prompt it sends is expected to fail with
// "API key is not set", which is precisely the path that proves the event
// pipeline works without touching the network.

import { spawn } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import readline from "node:readline";

const backend = process.argv[2];
if (!backend) {
    console.error("usage: node rpc_smoke.mjs <path-to-main.exe>");
    process.exit(2);
}

// spawn() resolves a *relative* program against the child's cwd, and the child
// below runs inside a temporary workspace — so the path has to be absolute
// before it is handed over, or the spawn fails with ENOENT.
const backendPath = path.resolve(backend);
if (!fs.existsSync(backendPath)) {
    console.error(`backend not found: ${backendPath}\n(build it first: dune build)`);
    process.exit(2);
}

const home = fs.mkdtempSync(path.join(os.tmpdir(), "minipi-home-"));
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "minipi-ws-"));

let failures = 0;
const check = (name, cond, extra = "") => {
    if (cond) {
        console.log(`  ok    ${name}`);
    } else {
        failures++;
        console.log(`  FAIL  ${name}${extra ? `\n        ${extra}` : ""}`);
    }
};

const child = spawn(backendPath, ["--mode", "rpc"], {
    cwd: workspace,
    // Pin HOME so the run cannot touch the developer's ~/.mini-pi, and blank
    // out the variables that would otherwise select a model or supply a key.
    env: {
        ...process.env,
        HOME: home,
        USERPROFILE: home,
        FIREWORKS_API_KEY: "",
        MODEL: "",
    },
    // stderr must be piped (not "inherit"): the checks below collect it into
    // stderrTail, and "inherit" leaves child.stderr null.
    stdio: ["pipe", "pipe", "pipe"],
});

const events = [];
const responses = [];
let stderrTail = "";

readline.createInterface({ input: child.stdout }).on("line", (line) => {
    let parsed;
    try {
        parsed = JSON.parse(line);
    } catch {
        // A non-JSON line on stdout would corrupt the channel: record it.
        events.push({ type: "__invalid__", line });
        return;
    }
    if (parsed.type === "response") responses.push(parsed);
    else events.push(parsed);
});

child.stderr.on("data", (d) => (stderrTail += d.toString()));

let counter = 0;
const pending = new Map();

const send = (request) =>
    new Promise((resolve, reject) => {
        const id = `req_${++counter}`;
        const timeout = setTimeout(() => reject(new Error(`timeout on ${request.type}`)), 20000);
        pending.set(id, { resolve: (r) => (clearTimeout(timeout), resolve(r)), reject });
        child.stdin.write(JSON.stringify({ ...request, id }) + "\n");
    });

// Route responses to their waiter as they arrive.
const originalPush = responses.push.bind(responses);
responses.push = (r) => {
    originalPush(r);
    if (r.id && pending.has(r.id)) {
        const w = pending.get(r.id);
        pending.delete(r.id);
        w.resolve(r);
    }
    return responses.length;
};

const waitFor = (predicate, ms = 8000) =>
    new Promise((resolve) => {
        const started = Date.now();
        const tick = () => {
            if (predicate()) return resolve(true);
            if (Date.now() - started > ms) return resolve(false);
            setTimeout(tick, 25);
        };
        tick();
    });

const run = async () => {
    console.log("mini-pi OCaml backend: RPC protocol smoke test\n");

    // --- state ---------------------------------------------------------
    let r = await send({ type: "get_state" });
    check("get_state succeeds", r.success === true, JSON.stringify(r));
    check("get_state echoes request_type", r.request_type === "get_state");
    check("get_state carries the model name", typeof r.data?.model === "string" && r.data.model.length > 0);
    check("get_state nulls the optional session fields",
        r.data?.session_id === null && r.data?.session_name === null,
        JSON.stringify(r.data));

    // --- extension commands -------------------------------------------
    r = await send({ type: "get_extension_commands" });
    check("get_extension_commands succeeds", r.success === true);
    const names = (r.data?.commands ?? []).map((c) => c.name);
    check("bundled permission command is exposed", names.includes("permission"), JSON.stringify(names));
    check("commands carry descriptions",
        (r.data?.commands ?? []).every((c) => typeof c.description === "string" && c.description.length > 0));

    // --- sessions ------------------------------------------------------
    r = await send({ type: "list_sessions" });
    check("list_sessions succeeds", r.success === true);
    check("list_sessions returns an empty array initially", Array.isArray(r.data?.rows) && r.data.rows.length === 0);

    r = await send({ type: "new_session" });
    check("new_session succeeds", r.success === true);
    const sessionId = r.data?.session_id;
    check("new_session returns an id", typeof sessionId === "string" && sessionId.length > 0, JSON.stringify(r.data));
    check("new_session starts empty", Array.isArray(r.data?.messages) && r.data.messages.length === 0);

    r = await send({ type: "get_rewind_targets" });
    check("get_rewind_targets succeeds", r.success === true);
    check("no rewind targets in a fresh session", Array.isArray(r.data?.targets) && r.data.targets.length === 0);

    // --- auth ----------------------------------------------------------
    r = await send({ type: "login", provider: "fireworks", key: "fw_test_key" });
    check("login succeeds", r.success === true);
    const authPath = path.join(home, ".mini-pi", "auth.json");
    check("login persists the key", fs.existsSync(authPath));
    if (fs.existsSync(authPath)) {
        let parsed = null;
        try {
            parsed = JSON.parse(fs.readFileSync(authPath, "utf8"));
        } catch (e) {
            parsed = null;
        }
        check("auth file stores the provider key", parsed?.fireworks === "fw_test_key", JSON.stringify(parsed));
    }

    r = await send({ type: "logout", provider: "fireworks" });
    check("logout succeeds", r.success === true);

    // --- error handling ------------------------------------------------
    r = await send({ type: "nonexistent_request" });
    check("unknown request type is rejected", r.success === false && r.request_type === "parse_error", JSON.stringify(r));

    r = await send({ type: "resume", session_id: "does-not-exist-anywhere" });
    check("resuming an unknown session fails", r.success === false && typeof r.error === "string", JSON.stringify(r));

    child.stdin.write("this is not json\n");
    const gotParseError = await waitFor(() =>
        responses.some((x) => x.request_type === "parse_error" && x.success === false));
    check("malformed json yields a parse_error response", gotParseError);

    // --- the event pipeline --------------------------------------------
    // A prompt with no API key configured must still produce a complete,
    // well-formed event sequence ending in an errored assistant message.
    const before = events.length;
    r = await send({ type: "prompt", message: "hello there" });
    check("prompt is acknowledged immediately", r.success === true && r.request_type === "prompt", JSON.stringify(r));

    const finished = await waitFor(() => events.slice(before).some((e) => e.type === "agent_end"));
    check("agent_end is emitted", finished);

    const seq = events.slice(before).map((e) => e.type);
    const order = [
        "agent_start",
        "message_start",
        "message_end",
        "turn_start",
        "message_start",
        "message_end",
        "turn_end",
        "agent_end",
    ];
    let cursor = -1;
    let ordered = true;
    for (const want of order) {
        const at = seq.indexOf(want, cursor + 1);
        if (at === -1) {
            ordered = false;
            break;
        }
        cursor = at;
    }
    check("event sequence follows the documented order", ordered, seq.join(" -> "));

    check("no non-JSON line ever reached stdout",
        !events.some((e) => e.type === "__invalid__"),
        JSON.stringify(events.find((e) => e.type === "__invalid__")));

    const errMsg = events.slice(before).find(
        (e) => e.type === "message_end" && e.message?.role === "assistant" && e.message?.stop_reason === "error");
    check("the assistant message reports the missing key", !!errMsg && /API key/i.test(errMsg.message.error_message),
        JSON.stringify(errMsg));

    const ended = events.slice(before).find((e) => e.type === "agent_end");
    check("agent_end carries the produced messages",
        Array.isArray(ended?.messages) && ended.messages.length === 2 &&
        ended.messages[0].role === "user" && ended.messages[1].role === "assistant",
        JSON.stringify(ended));

    // --- abort ---------------------------------------------------------
    r = await send({ type: "abort" });
    check("abort succeeds", r.success === true);

    child.kill();
};

run()
    .catch((e) => {
        failures++;
        console.log(`  FAIL  harness error: ${e.message}`);
    })
    .finally(() => {
        if (stderrTail.trim()) console.log(`\n[backend stderr]\n${stderrTail.trim()}`);
        // The backend was spawned with the workspace as its cwd; on Windows that
        // handle outlives the process briefly, so retry the removal instead of
        // letting an EBUSY mask the result.
        const rmTemp = (dir) => {
            try {
                fs.rmSync(dir, { recursive: true, force: true, maxRetries: 20, retryDelay: 100 });
            } catch (e) {
                console.log(`  (note: could not remove ${dir}: ${e.code})`);
            }
        };
        rmTemp(home);
        rmTemp(workspace);
        console.log(`\n${failures === 0 ? "ALL CHECKS PASSED" : "FAILURES PRESENT"} (${failures} failure${failures === 1 ? "" : "s"})`);
        process.exit(failures === 0 ? 0 : 1);
    });
