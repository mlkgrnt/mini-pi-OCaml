#!/usr/bin/env python3
"""Generate lib/ai_catalog.ml -- the built-in provider catalog.

    python tools/gen_providers.py                # use the cached snapshot
    python tools/gen_providers.py --fetch        # refresh the snapshot first

Why a generator, and why this data source
-----------------------------------------
Hand-writing a provider list means hand-writing base URLs, environment variable
names, context windows and model ids, and every one of those is a fact that goes
stale. models.dev is the dataset the OpenCode agent uses for the same job; it is
machine-readable, covers ~230 providers, and states which providers speak the
OpenAI wire format. So the catalog is derived from it rather than invented, and
this script is committed next to the output so the derivation can be re-run and
checked.

What is taken verbatim
----------------------
For a provider whose entry says `npm: @ai-sdk/openai-compatible`, models.dev is
also the source of the base URL, and the AI SDK builds `<base>/chat/completions`
from it -- the same URL this port builds. Those entries are copied as-is.

What is not
-----------
Two groups of providers need a base URL that models.dev does not carry, because
for them the default lives inside a first-party SDK (`api: null` in the
dataset): OpenAI, Anthropic, Google, xAI, Groq, Mistral, Cerebras, Together,
DeepInfra. Each of those is listed in VERIFIED with the documentation that
states the URL, so the claim is checkable instead of remembered. Anthropic and
Google are reached through their own OpenAI-compatibility shims, which is worth
knowing about: Anthropic's shim documents that it does not return thinking
content and calls itself not production-ready.

Deliberate exclusions
---------------------
Each one is listed in EXCLUDED with the reason. Note in particular that being in
models.dev is not sufficient: a provider also has to be reachable with an API
key alone.
"""

import argparse
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SNAPSHOT = os.path.join(ROOT, ".deps", "models.dev.api.json")
SOURCE_URL = "https://models.dev/api.json"
OUTPUT = os.path.join(ROOT, "lib", "ai_catalog.ml")

MAX_MODELS_PER_PROVIDER = 12

# SDK packages that construct "<base_url>/chat/completions", i.e. the request this
# port sends. Providers using anything else (an Anthropic-shaped or Bedrock-shaped
# API, say) are left out however explicit their base URL looks, because the
# serializer would be wrong.
OPENAI_SHAPED_SDKS = {
    "@ai-sdk/openai",
    "@ai-sdk/openai-compatible",
    "@openrouter/ai-sdk-provider",
}

# Fallback for the handful of models whose published output limit is missing or
# zero. Not a guess about the model: both compaction and overflow detection only
# need an upper bound, and this is deliberately below every real limit so the
# error is on the safe side.
DEFAULT_MAX_TOKENS = 8192

# --- providers taken verbatim from models.dev ------------------------------
# Both the base URL and the model metadata come from the dataset for these.
# They follow the VERIFIED list in the output, so this is the order of the
# regional labs and hosting platforms behind the first-party vendors.
CATALOG = [
    # First-party labs
    "deepseek", "moonshotai", "moonshotai-cn", "zhipuai", "zai", "meta",
    "alibaba", "alibaba-cn", "siliconflow", "siliconflow-cn", "stepfun",
    "stepfun-ai", "xiaomi", "sensenova", "longcat", "upstage", "inception",
    "ai21", "sakana", "arcee", "llama",
    # Clouds and inference platforms
    "nvidia", "tencent-tokenhub", "volcengine", "qiniu-ai", "modelscope",
    "baseten", "nebius", "novita-ai", "friendli", "chutes", "scaleway",
    "ovhcloud", "vultr", "crusoe", "digitalocean", "gmicloud", "hetzner",
    "ollama-cloud",
    # Aggregators
    "openrouter", "poe", "requesty", "zenmux", "nano-gpt",
    # Local servers
    "lmstudio",
]

# --- providers whose base URL comes from their own documentation -----------
# `api` in models.dev, `npm`, `source` = where the URL is stated.
VERIFIED = [
    {
        "id": "openai",
        "override": "https://api.openai.com/v1",
        "source": "https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml (servers: url)",
        "why": "models.dev leaves api null; the base URL is in the official OpenAPI document",
    },
    {
        "id": "anthropic",
        "override": "https://api.anthropic.com/v1",
        "source": "https://platform.claude.com/docs/en/api/openai-sdk",
        "why": "Anthropic's own OpenAI-compatibility shim; the docs also state it does "
               "not return thinking content and is not intended for production use",
    },
    {
        "id": "google",
        "override": "https://generativelanguage.googleapis.com/v1beta/openai",
        "source": "https://ai.google.dev/gemini-api/docs/openai",
        "why": "Gemini's OpenAI-compatibility endpoint; the /openai suffix is required",
    },
    {
        "id": "xai",
        "override": "https://api.x.ai/v1",
        "source": "https://docs.x.ai/docs/api-reference",
        "why": "documented with OpenAI SDK examples",
    },
    {
        "id": "groq",
        "override": "https://api.groq.com/openai/v1",
        "source": "https://console.groq.com/docs/openai",
        "why": "documented as the drop-in base_url for OpenAI clients",
    },
    {
        "id": "mistral",
        "override": "https://api.mistral.ai/v1",
        "source": "https://docs.mistral.ai/getting-started/quickstarts/developer/first-api-request",
        "why": "documented endpoint; the OpenAI SDK is used against /v1/chat/completions",
    },
    {
        "id": "cerebras",
        "override": "https://api.cerebras.ai/v1",
        "source": "https://inference-docs.cerebras.ai/api-reference/chat-completions",
        "why": "OpenAPI declares servers.url https://api.cerebras.ai with path /v1/chat/completions",
    },
    {
        "id": "togetherai",
        "override": "https://api.together.ai/v1",
        "source": "https://docs.together.ai/docs/inference/openai-compatibility",
        "why": "documented as the drop-in base_url for OpenAI clients",
    },
    {
        "id": "deepinfra",
        "override": "https://api.deepinfra.com/v1/openai",
        "source": "https://docs.deepinfra.com/chat/overview",
        "why": "documented as the OpenAI-compatible endpoint",
    },
]

# --- present in models.dev, deliberately left out --------------------------
EXCLUDED = {
    "fireworks-ai": "the upstream bundled `fireworks` provider already registers this vendor "
                    "(extensions/bundled/providers/fireworks.py); two entries would be one too many",
    "opencode": "models.dev points at https://opencode.ai/zen/v1, which answers 403 to API keys: "
                "it serves OpenCode's own product. The endpoint that does accept a key is "
                "https://opencode.ai/inference/openai/v1, registered by live/live_opencode.ml",
    "opencode-go": "https://opencode.ai/zen/go/v1 requires a separate Go subscription, so an API "
                   "key alone is not enough",
    "github-copilot": "authentication is a GitHub Copilot token exchange, not a provider API key",
    "minimax": "models.dev gives it npm @ai-sdk/anthropic, i.e. an Anthropic-shaped API, which "
               "this port's OpenAI serializer cannot drive",
    "perplexity-agent": "models.dev gives base https://api.perplexity.ai/v1, but Perplexity's docs "
                        "put the Agent API at /v1/agent and point OpenAI clients at the Router API, "
                        "https://api.perplexity.ai/router/v1, so the dataset's URL does not look "
                        "like a chat/completions base. Worth adding once someone has a key to "
                        "confirm which it is",
}


def usable(model):
    """Does this model make sense for a coding agent driven by this port?"""
    if not model.get("tool_call"):
        return False  # the agent loop is built on tool calls
    if "text" not in (model.get("modalities") or {}).get("output", []):
        return False  # image/embedding-only models cannot answer
    return (model.get("limit") or {}).get("context", 0) > 0


def rank(model):
    """Order models so the cap keeps the most useful ones."""
    limit = model.get("limit") or {}
    return (
        1 if model.get("reasoning") else 0,
        limit.get("context", 0),
        model.get("last_updated") or "",
    )


def ocaml_string(value):
    out = ['"']
    for ch in value:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def build_model(mid, m):
    limit = m.get("limit") or {}
    context_window = limit["context"]
    max_tokens = limit.get("output") or 0
    if max_tokens <= 0:
        max_tokens = DEFAULT_MAX_TOKENS
    # An output limit larger than the whole window is nonsense, and compaction
    # reads context_window while overflow detection reads max_tokens, so the two
    # disagreeing would be a confusing bug rather than a loud one.
    max_tokens = min(max_tokens, context_window)
    return {
        "id": mid,
        "label": m.get("name") or mid,
        "context_window": context_window,
        "max_tokens": max_tokens,
        "reasoning": bool(m.get("reasoning")),
    }


def collect(data):
    providers = []
    notes = []

    def add(pid, entry, base_url, doc, origin, extra_models=None):
        models = entry.get("models", {})
        picked = sorted(
            ((mid, m) for mid, m in models.items() if usable(m)),
            key=lambda kv: rank(kv[1]),
            reverse=True,
        )
        if not picked:
            notes.append("skipped %s: no tool-calling text model" % pid)
            return
        if len(picked) > MAX_MODELS_PER_PROVIDER:
            notes.append(
                "%s: kept %d of %d usable models"
                % (pid, MAX_MODELS_PER_PROVIDER, len(picked))
            )
            picked = picked[:MAX_MODELS_PER_PROVIDER]
        env = entry.get("env") or []
        if not env:
            notes.append("skipped %s: no environment variable to read a key from" % pid)
            return
        providers.append(
            {
                "id": pid,
                "label": entry.get("name") or pid,
                "base_url": base_url.rstrip("/"),
                "env": env,
                "doc": doc,
                "origin": origin,
                "models": [build_model(mid, m) for mid, m in picked],
            }
        )

    # VERIFIED first on purpose. These are the vendors a user is most likely to
    # arrive with a key for, so they lead the list the UI renders; CATALOG then
    # supplies the regional labs and the hosting platforms behind them.
    for spec in VERIFIED:
        pid = spec["id"]
        entry = data.get(pid)
        if entry is None:
            notes.append("skipped %s: absent from the snapshot" % pid)
            continue
        add(pid, entry, spec["override"], entry.get("doc") or "", spec["source"])

    for pid in CATALOG:
        entry = data.get(pid)
        if entry is None:
            notes.append("skipped %s: absent from the snapshot" % pid)
            continue
        if entry.get("npm") not in OPENAI_SHAPED_SDKS:
            notes.append(
                "skipped %s: npm is %s, not an OpenAI-shaped SDK"
                % (pid, entry.get("npm"))
            )
            continue
        if not entry.get("api"):
            notes.append(
                "skipped %s: npm is OpenAI-shaped but the snapshot carries no base URL"
                % pid
            )
            continue
        add(pid, entry, entry["api"], entry.get("doc") or "", "models.dev")

    return providers, notes


def render(providers, snapshot_note):
    total_models = sum(len(p["models"]) for p in providers)
    lines = []
    lines.append("(* Built-in provider catalog. GENERATED -- do not edit by hand.")
    lines.append(" *")
    lines.append(" *   python tools/gen_providers.py [--fetch]")
    lines.append(" *")
    lines.append(" * %s" % snapshot_note)
    lines.append(" *   providers: %d   models: %d" % (len(providers), total_models))
    lines.append(" *")
    lines.append(" * Every entry speaks OpenAI Chat Completions, which is the only wire format")
    lines.append(" * this port implements. Base URLs and model metadata are taken from the source")
    lines.append(" * above; where a provider's URL is not in it, the documentation that states")
    lines.append(" * the URL is named in [doc]. The rules, and the providers left out, are in")
    lines.append(" * tools/gen_providers.py. *)")
    lines.append("")
    lines.append("let providers : Ai_catalog_spec.provider list = [")
    for p in providers:
        lines.append("  {")
        lines.append("    Ai_catalog_spec.id = %s;" % ocaml_string(p["id"]))
        lines.append("    label = %s;" % ocaml_string(p["label"]))
        lines.append("    base_url = %s;" % ocaml_string(p["base_url"]))
        lines.append(
            "    env = [ %s ];" % "; ".join(ocaml_string(e) for e in p["env"])
        )
        lines.append("    doc = %s;" % ocaml_string(p["doc"]))
        lines.append("    models = [")
        for m in p["models"]:
            lines.append("      {")
            lines.append("        Ai_catalog_spec.id = %s;" % ocaml_string(m["id"]))
            lines.append("        label = %s;" % ocaml_string(m["label"]))
            lines.append("        context_window = %d;" % m["context_window"])
            lines.append("        max_tokens = %d;" % m["max_tokens"])
            lines.append("        reasoning = %s;" % ("true" if m["reasoning"] else "false"))
            lines.append("      };")
        lines.append("    ];")
        lines.append("  };")
    lines.append("]")
    lines.append("")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fetch", action="store_true", help="refresh the models.dev snapshot")
    ap.add_argument("--check", action="store_true",
                    help="exit non-zero if the output would change (for CI)")
    args = ap.parse_args()

    if args.fetch or not os.path.exists(SNAPSHOT):
        os.makedirs(os.path.dirname(SNAPSHOT), exist_ok=True)
        print("fetching %s -> %s" % (SOURCE_URL, SNAPSHOT))
        urllib.request.urlretrieve(SOURCE_URL, SNAPSHOT)

    with open(SNAPSHOT, encoding="utf-8") as fh:
        data = json.load(fh)

    providers, notes = collect(data)

    # A duplicate id would make the second registration raise at startup.
    ids = [p["id"] for p in providers]
    if len(ids) != len(set(ids)):
        raise SystemExit("duplicate provider id: %s" % sorted(ids))

    snapshot_note = "Source: %s (snapshot at .deps/models.dev.api.json)." % SOURCE_URL
    text = render(providers, snapshot_note)

    if args.check:
        current = open(OUTPUT, encoding="utf-8").read() if os.path.exists(OUTPUT) else ""
        if current != text:
            print("FAIL: %s is stale; re-run tools/gen_providers.py" % OUTPUT)
            return 1
        print("ok: %s is up to date" % OUTPUT)
        return 0

    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)

    print("wrote %s" % os.path.relpath(OUTPUT, ROOT))
    print("  providers: %d" % len(providers))
    print("  models:    %d" % sum(len(p["models"]) for p in providers))
    for note in notes:
        print("  note: %s" % note)
    return 0


if __name__ == "__main__":
    sys.exit(main())
