"""Ask a provider directly how much reasoning it emits, and under which framing.

Written because a live run through the port reported "no reasoning_content"
while a hand-written curl command showed plenty. The question this answers is
which of the two shapes the difference lives in -- prompt, or the presence of a
tools array -- without involving the port's own code at all.

    OPENCODE_API_KEY=sk-... python tools/probe_reasoning.py

Read-only and self-contained: it makes four requests and prints the number of
reasoning, text and tool-call delta characters seen on the raw wire for each.
"""

import json, os, urllib.request

KEY = os.environ["OPENCODE_API_KEY"]
URL = "https://opencode.ai/inference/openai/v1/chat/completions"

LIVE_PROMPT = (
    "Create a file named report.txt in the current directory containing exactly: "
    "hello from opencode\nThen reply with the single word DONE."
)
SYSTEM = "You are a terse assistant."

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "write",
            "description": "Write content to a file in the workspace.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "description": "Relative path"},
                    "content": {"type": "string", "description": "File content"},
                },
                "required": ["path", "content"],
            },
        },
    }
]


def build(prompt, tools):
    body = {
        "messages": [
            {"role": "system", "content": SYSTEM},
            {"role": "user", "content": prompt},
        ],
        "model": "deepseek-v4.1-flash",
        "stream": True,
        "stream_options": {"include_usage": True},
    }
    if tools:
        body["tools"] = TOOLS
    return body


def probe(label, prompt, tools):
    data = json.dumps(build(prompt, tools)).encode()
    req = urllib.request.Request(
        URL,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer " + KEY,
            # The gateway answers 403 to an unknown User-Agent (Python-urllib is
            # rejected outright). curl's own UA is accepted -- which is exactly
            # what the OCaml port gets for free, since it shells out to curl.
            "User-Agent": "curl/8.14.1",
        },
    )
    think = 0
    text = 0
    tool_calls = 0
    with urllib.request.urlopen(req, timeout=120) as resp:
        for raw in resp:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            payload = line[5:].strip()
            if payload == "[DONE]":
                break
            try:
                chunk = json.loads(payload)
            except Exception:
                continue
            for choice in chunk.get("choices") or []:
                delta = choice.get("delta") or {}
                for field in ("reasoning_content", "reasoning", "thinking", "reasoning_text"):
                    v = delta.get(field)
                    if isinstance(v, str) and v:
                        think += len(v)
                        break
                if delta.get("content"):
                    text += len(delta["content"])
                if delta.get("tool_calls"):
                    tool_calls += len(delta["tool_calls"])
    print(f"  {label:<44} thinking={think:>5} chars  text={text:>4}  tool_deltas={tool_calls}")


print("model=deepseek-v4.1-flash  (thinking chars seen on the raw wire)")
probe("A. live prompt, no tools", LIVE_PROMPT, False)
probe("B. live prompt, one 'write' tool", LIVE_PROMPT, True)
probe("C. reasoning-heavy prompt, no tools", "How many r letters are in strawberry? Reason first.", False)
probe("D. reasoning-heavy prompt, one tool", "How many r letters are in strawberry? Reason first.", True)
