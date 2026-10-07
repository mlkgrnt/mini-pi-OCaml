# mini-pi (OCaml port)

A port of [nik-55/mini-pi](https://github.com/nik-55/mini-pi) — a minimal coding
agent — from Python to OCaml.

The upstream project is around 5,700 lines of Python across three layers, plus a
1,900-line TypeScript terminal UI that talks to the backend over newline
delimited JSON on stdin/stdout. This port reproduces all three layers and keeps
the RPC protocol byte-compatible, so the **original TypeScript TUI drives the
OCaml backend unchanged**.

```
lib/                     OCaml library (module names mirror the Python layout)
  ai_types.ml            ai/types.py            messages, events, model, tool, context
  ai_cancellation.ml     ai/cancellation.py     cancellation signal
  ai_registry.ml         ai/registry.py         provider registry + credential lookup
  ai_catalog_spec.ml     -                      types for the generated provider catalog
  ai_catalog.ml          (bundled providers)    generated: 54 providers, 478 models
  ai_openai.ml           ai/api/openai_*/       serializer, SSE parser, streaming client
  ai_retry.ml            ai/provider_retry.py   retry policy, backoff, Retry-After
  ai_transform.ml        ai/transform.py        repair transcripts with dangling tool calls
  ai_validation.ml       ai/validation.py       JSON-schema subset for tool arguments
  ai_overflow.ml         ai/overflow.py         context-overflow detection
  ai_http.ml             (httpx)                HTTP transport
  ai_json.ml             -                      total JSON accessors
  proc_util.ml           -                      subprocess + pipe plumbing
  agent_events.ml        agent/events.py        event vocabulary
  agent_tools.ml         agent/tools.py         tool descriptor + closure
  agent_queue.ml         agent/queue.py         steering / follow-up queues
  agent_loop.ml          agent/loop.py          the agent loop
  agent_harness.ml       agent/harness.py       history, listeners, cancellation
  coding_messages.ml     coding/messages.py     session message + LLM conversion
  coding_events.ml       coding/events.py       session events + wire encoding
  coding_tool_utils.ml   coding/tools/utils.py  truncation, path resolution
  coding_tools.ml        coding/tools/*.py      read / write / edit / bash
  coding_auth.ml         coding/auth.py         ~/.mini-pi/auth.json
  coding_settings.ml     coding/settings.py     ~/.mini-pi/settings.json
  coding_context.ml      coding/context.py      AGENTS.md + .agents/skills
  coding_entries.ml      coding/session_manager/entries.py
  coding_traversal.ml    coding/session_manager/traversal.py
  coding_session_manager.ml coding/session_manager/manager.py
  coding_compaction.ml   coding/compaction/*.py token estimation, cut points, summarizer
  coding_extensions.ml   coding/extensions/*.py  hooks, tools, commands, UI, bundled ext
  coding_session.ml      coding/session.py      session facade
  coding_session_runtime.ml coding/session_runtime.py
  coding_session_factory.ml coding/session_factory.py
  coding_commands.ml     coding/commands.py     slash command table
  coding_cli.ml          coding/modes/cli/      REPL
  coding_rpc.ml          coding/modes/rpc/      JSON-RPC server
  coding_main.ml         coding/main.py + entrypoint.py
bin/main.ml              executable entry point
tui/                     the original TypeScript TUI, with the backend launch patched
live/                    checks that need a real provider (never run by `dune runtest`)
  live_opencode.ml       end-to-end run against OpenCode: tool round trip, usage,
                         reasoning, and the failure path for a rejected key
  transport_probe.ml     holds curl's argv fixed and varies only the body source,
                         to locate a request that hangs before it is sent
tools/                   support scripts
  build-deps.sh          builds and installs the dependency closure from source
  dump_wire_json.py      regenerates the wire-format reference from the Python original
  gen_providers.py       regenerates lib/ai_catalog.ml from models.dev (--fetch, --check)
  probe_endpoints.py     checks every catalog base URL really is a chat/completions endpoint
  probe_reasoning.py     asks a provider directly whether it emits reasoning_content
```

## Build

Requires dune plus the `cppo`, `csexp`, `ocplib-endian`, `dune-configurator`,
`lwt` and `yojson` packages.

```sh
opam install dune cppo csexp ocplib-endian dune-configurator lwt yojson
dune build
```

The binary lands at `_build/default/bin/main.exe`.

Three things worth knowing on Windows, where this was developed:

- **Use OCaml 4.14.x.** 5.3.0 does not build against the mingw/Cygwin toolchain
  opam installs here: `otherlibs/dynlink/byte/dynlink_symtable.ml` fails with
  `Unbound type constructor "compunit"`, deterministically and at any `-j`.
- `dune` must not run under a file-locking sandbox, and a stale `_build/.lock`
  left by an interrupted run makes every later invocation fail with a
  misleading `open(_build/.lock): Permission denied`. `rm -rf _build` cures it.
- Native compilation needs the mingw assembler (`x86_64-w64-mingw32-as`) on
  `PATH`; without it `ocamlopt` dies with `Assembler error, input left in
  file ...camlasm*.s`. The assembler ships inside opam's managed Cygwin, at
  `<opam-root>/.cygwin/root/bin`.

The shell environment used during development is `E:/ocaml/ocaml-env.sh`, which
must be sourced before any `opam`/`dune` command — it removes the shell's `rm`
shim (whose CRLF line endings make opam's configure fail) and puts the switch
and mingw toolchains on `PATH`.

`opam install` does not work on this machine: it hangs in its archive extraction
step, producing a zero-byte log and no child process. `tools/build-deps.sh`
therefore builds and installs the entire closure from source, in dependency
order:

```
dune → cppo → csexp → ocplib-endian → dune-configurator → lwt → yojson
```

Two of those are easy to miss: `dune-configurator` is not a downloadable tarball
(it ships inside the dune source tree) and `csexp` is only reachable through it.
The script is idempotent and documents each trap it works around.

## Run

```sh
# REPL, line-oriented
dune exec bin/main.exe -- --mode cli

# JSON-RPC backend, the mode the TUI drives
dune exec bin/main.exe -- --mode rpc

# Hand the terminal to the TypeScript TUI (built below)
dune exec bin/main.exe
```

Point the TUI at the binary explicitly if you have moved things around:

```sh
MINI_PI_BIN=/path/to/main.exe node tui/dist/index.js
```

### Building the TUI

```sh
cd tui
npm install
npm run bundle     # writes ../tui_dist/mini-pi-tui.mjs
```

`tui/src/rpc_client.ts` resolves the backend in this order: `MINI_PI_BIN`,
`_build/default/bin/main.exe`, then the original `python -P -m coding.main`.
The rest of the TUI is the upstream code, unmodified.

## Setup

```sh
cd /path/to/your/workspace
minipi
/login fireworks fw_XXXX     # key is stored in ~/.mini-pi/auth.json
/help
```

`MODEL=fireworks:accounts/fireworks/models/minimax-m3` selects a model without
touching settings; a `default_model_ref` in `~/.mini-pi/settings.json` wins.

## Provider catalog

`install_bundled` registers **54 providers carrying 478 models** at startup, so a
key is the only thing needed to use one:

```sh
minipi
/login openai sk-...                 # or: export OPENAI_API_KEY=sk-...
MODEL=deepseek:deepseek-v4-pro minipi
```

Coverage is the first-party labs (OpenAI, Anthropic, Gemini, xAI, Groq, Mistral,
Cerebras, Together, DeepInfra), the Chinese labs and platforms (DeepSeek,
Moonshot, Zhipu/Z.ai, Alibaba, SiliconFlow, StepFun, Xiaomi, Tencent TokenHub,
Volcano Engine, ModelScope), the large inference hosts (NVIDIA, Baseten, Nebius,
Novita, Scaleway, Vultr, DigitalOcean, …), the aggregators (OpenRouter, Poe,
Requesty, Nano-GPT, ZenMux) and local servers (LM Studio, Ollama Cloud).

Keys resolve exactly as they do for the upstream providers — `/login`, then
`~/.mini-pi/auth.json`, then the environment. A catalog entry may name several
environment variables (`GOOGLE_API_KEY,GOOGLE_GENERATIVE_AI_API_KEY,GEMINI_API_KEY`
for Gemini, because vendors rename these and users have the old ones exported);
the first that is set *and non-empty* wins, so a stale empty variable does not
mask a working one.

### Where the data comes from

`lib/ai_catalog.ml` is **generated, not hand-written** — base URLs, environment
variable names, context windows and model ids are all facts that rot, and
hand-typing several hundred of them guarantees a few wrong ones. The source is
[models.dev](https://models.dev/api.json), the same machine-readable dataset the
OpenCode agent uses for this job, snapshotted to `.deps/models.dev.api.json`:

```sh
python tools/gen_providers.py            # regenerate from the cached snapshot
python tools/gen_providers.py --fetch    # refresh the snapshot first
python tools/gen_providers.py --check    # non-zero exit if the output is stale
```

`--check` is the guard against the generated file drifting away from the rules
in the script; `test/test_mini_pi.ml` independently asserts the invariants that
would otherwise rot silently (no duplicate ids, no trailing slash on a base URL,
every model positive limits, every entry actually registered).

### What is allowed in

This port implements exactly one wire format — OpenAI Chat Completions — so the
catalog only contains providers that speak it. Two tiers:

| Tier | Base URL from | Example |
| --- | --- | --- |
| verbatim | the dataset's `api` field | DeepSeek, OpenRouter, the clouds |
| `VERIFIED` | the vendor's own documentation, named per entry | OpenAI, Anthropic, Gemini, xAI, Groq, Mistral, Cerebras, Together, DeepInfra |

The second tier exists because models.dev leaves `api` null for providers whose
default endpoint lives inside a first-party SDK. Each `VERIFIED` entry records
the document that states the URL, so the claim is checkable rather than
remembered. Two of them are OpenAI-compatibility shims rather than native
surfaces — Anthropic's shim documents that it *does not return thinking content*
and calls itself not production-ready, which is worth knowing before wondering
where the reasoning went.

### What is left out

Being in models.dev is not sufficient. The `EXCLUDED` map in the generator
records the reason for each one:

- **Anthropic- or Bedrock-shaped APIs** (MiniMax, and Bedrock/Vertex endpoints):
  the dataset says so via `npm: @ai-sdk/anthropic`, and this port's serializer
  would produce the wrong request body.
- **Providers an API key alone cannot reach**: GitHub Copilot (a token exchange),
  OpenCode's own `/zen/go/v1` (a separate subscription).
- **Already registered**: Fireworks, by the bundled upstream extension.
- **Unconfirmed endpoints**: Perplexity's Agent API, where the dataset URL does
  not look like a `chat/completions` base.

At most 12 models are kept per provider, ranked reasoning-first then by context
window, which is why OpenRouter contributes 12 of its 322 usable models.

### Checking the base URLs

A base URL is the one field in the catalog that is neither derived from a schema
nor checked by the compiler, and a typo in it only shows up the first time
somebody asks a question. So there is a second tool:

```sh
python tools/probe_endpoints.py                        # every provider
python tools/probe_endpoints.py openai anthropic google
```

It sends one deliberately unauthorised request to each `<base_url>/chat/completions`
and reports the status. The useful answer is the *rejection*: a 401, 403 or 400
means the endpoint exists and refused the request, which is what proves the URL
right. A 404 is the failure it is looking for. The model name in the probe comes
from the catalog, because a gateway that routes by model otherwise answers "no
backend for that model" — a 404 that says the path is fine and only the name is
wrong.

Last run: **53 of 54 answered as real endpoints.** The exception was LM Studio,
whose `http://127.0.0.1:1234/v1` had no server running — which is also the only
provider that needs something other than a key.

## Deliberate divergences from the Python original

These are the places where a faithful translation was not possible or not
sensible. Everything else is intended to behave identically.

1. **Extension loading.** Upstream imports third-party extension modules with
   `importlib` at runtime. An OCaml binary cannot host Python modules, so the
   *loading mechanism* is different while the *runtime semantics* are not:
   - the bundled extensions (`permission_gate`, the `fireworks` provider) are
     compiled in and installed natively;
   - external extensions are described by a JSON descriptor in
     `.mini-pi/extensions/bundled/`, able to block a tool call, rewrite or
     absorb an input, emit a notification and expose a slash command.

   Hook ordering, result types, tool wrapping and input hook chaining follow the
   Python runtime exactly.

2. **HTTP transport.** Upstream uses `httpx`. This port shells out to `curl`
   instead, which keeps TLS, proxy handling and certificate validation out of
   the dependency tree and works identically on Windows and Unix. `post_stream`
   in `ai_http.ml` is the single entry point, so replacing it with a native
   client is a one-function change.

   Shelling out has one consequence worth knowing about, because it is invisible
   until it goes wrong: with `-i`, the output is not always a single response
   head. Behind a proxy it is two — the proxy's reply to `CONNECT`, then the
   origin's real response — and a parser that ends the head at the first blank
   line takes the proxy's `200` for the real status. Every upstream error would
   then be reported as a missing `finish_reason`. `ai_http.ml` parses the head
   with an explicit state machine (`reader_line`) that only accepts the last
   block, and it is covered offline by the "HTTP response head parsing" tests.

   When a live run behaves differently from the same request typed into `curl`
   by hand, set `MINI_PI_HTTP_DUMP=<path>`. Every line curl produces is written
   there verbatim, headers included, and the request body is written to
   `<path>.request`. The parsed event stream cannot show a field the server never
   sent, so this is the only way to tell "the provider omitted it" from "we
   dropped it".

3. **Subprocess I/O.** On Windows `select` does not work on pipes, so a child's
   output cannot be handed to the Lwt event loop. Blocking reads happen on
   preemptive worker threads and results are marshalled back with
   `Lwt_preemptive.run_in_main`. `proc_util.ml` isolates this.

4. **Async style.** Upstream's agent loop is an `async` generator. The OCaml
   loop is push-based: it takes an `emit` callback instead of yielding. Same
   sequencing, no generator machinery.

5. **Shell for the `bash` tool.** Upstream hardcodes `/bin/bash -c`. This port
   picks the platform shell (`cmd.exe /c` on Windows, `/bin/sh -c` elsewhere),
   overridable with `MINI_PI_SHELL`. The Linux-only `bwrap` sandbox is detected
   the same way as upstream; where it is absent, the `permission_gate`
   extension falls back to asking the user, exactly as before.

6. **Validation.** Upstream validates tool arguments with `jsonschema`. This
   port implements the subset the tools actually use: object shape, `required`,
   declared primitive types and array items. The `_raw_arguments` sentinel that
   the stream parser plants for truncated tool arguments is preserved.

## Protocol compatibility

The RPC channel carries one JSON object per line. Requests, responses, agent
events and extension-UI messages all follow `tui/src/types/rpc.ts` and
`tui/src/types/events.ts` verbatim, including null-valued fields that pydantic
emits by default. This is what lets the unmodified TUI drive either backend.

## Verification

`./verify.sh` runs everything; each stage can also run on its own
(`build`, `test`, `rpc`, `tui`). `./verify.sh ref` regenerates
`tools/wire_json_reference.txt` from the Python original so the wire format can
be diffed by hand.

| Stage | What it proves |
| --- | --- |
| `dune build` | all 37 modules compile |
| `dune runtest` | 119 offline assertions: JSON encoding, the SSE frame parser, response-head parsing, the generated provider catalog, truncation, compaction maths, the session/rewind tree, a full agent loop driven by a scripted provider, extension hooks |
| `test/rpc_smoke.mjs` | 28 assertions on the exact wire messages, driven over stdin/stdout the way the TUI drives them — including that no non-JSON line ever reaches stdout |
| `test/tui_client_check.mjs` | imports the compiled `tui/dist/rpc_client.js` and lets the real TUI client spawn the OCaml backend |

`./verify.sh all` exits non-zero if any stage fails.

Everything in the three suites runs offline: the only prompt sent is expected to
fail with "API key is not set", which is precisely the path that exercises the
whole event pipeline without touching the network. All three suites redirect
`HOME`, so a run can never touch the developer's real `~/.mini-pi`.

Two of the offline suites exist because a real provider turned out to disagree
with a hand-written `curl` command:

- **SSE frame parsing** (`OpenAI SSE stream parsing`). Every other test drives
  the agent loop with an already-parsed event list, so nothing exercised the step
  that turns a provider's JSON into events — including the `reasoning_content`
  field, tool arguments split across two deltas, the `_raw_arguments` sentinel for
  truncated arguments, `content_filter`, and an error payload embedded mid-stream.
- **Response-head parsing** (`HTTP response head parsing`), described under the
  transport divergence above.

## Live checks

These need a real key and are deliberately kept out of `dune runtest`, so the
offline suites stay reproducible.

```sh
OPENCODE_API_KEY=sk-... dune exec live/live_opencode.exe
OPENCODE_MODEL=glm-5.3  dune exec live/live_opencode.exe    # default: deepseek-v4.1-flash
```

`live_opencode.ml` registers the OpenCode inference endpoint
(`https://opencode.ai/inference/openai/v1`, OpenAI-compatible) and drives the
real agent loop: the model is asked to write a file, the tool runs, the result
goes back, and the loop ends. It asserts the event trace's shape, the file's
contents, the assistant message, and that usage was read out of the stream. It
then repeats the request with a deliberately invalid key, asserting that the
provider's own error body is surfaced.

Two things it does *not* assert, on purpose:

- **Reasoning.** These models emit `reasoning_content` on some calls and not
  others — measured, not assumed; see `tools/probe_reasoning.py`. A hard
  assertion would be testing the model's mood, so the run reports what it saw and
  the parser path is pinned down by the offline suite instead.
- **Context window and max output.** OpenCode's `/models` publishes only
  `id`/`object`/`created`/`owned_by`. Baking invented numbers into the library
  would silently skew compaction and overflow decisions, so the limits are an
  explicit assumption of the harness, declared at the top of the file.

## License

**Unresolved, and deliberately not papered over.** The upstream project
([nik-55/mini-pi](https://github.com/nik-55/mini-pi)) states no licence: its
`pyproject.toml` has no `license` field, it carries no `LICENSE` file, and its
README does not mention one. The vendored `tui/package.json` does carry a
`"license": "ISC"` field, but that looks like the `npm init` default rather than
a grant, and it would in any case only cover the TypeScript UI.

This repository is a derivative work of that project, so it inherits the same
ambiguity: absent a licence, the default is that all rights are reserved. Treat
it as source-available rather than open source, and ask upstream (or add a
licence once upstream states one) before relying on it for anything that
depends on a licence.
