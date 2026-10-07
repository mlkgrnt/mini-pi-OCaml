#!/usr/bin/env python3
"""Check that each catalog base URL really is a chat-completions endpoint.

    python tools/probe_endpoints.py [provider ...]

Reads the same source as the generator, then sends one deliberately
unauthorised request to "<base_url>/chat/completions" for every provider and
reports the status.

How to read the result
----------------------
The request carries a bogus key, so the useful answers are the *rejections*:

  401 / 403   the endpoint exists and refused us -- the URL is right
  400         exists, rejected the body  -- also fine, the URL is right
  404         wrong path: this is the failure this script is looking for
  000         no connection (DNS, TLS, or a local server that is not running)
  5xx         usually an upstream/proxy problem, not necessarily a bad URL

A 200 would be alarming, and would mean the provider ignored the key.

This exists because the base URLs are the one part of the catalog that is
neither derived from a schema nor checked by the compiler: a typo there shows up
as a 404 the first time a user actually asks a question.
"""

import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_providers as gen  # noqa: E402

def probe(base_url, model_id):
    # The model name matters for the verdict. A gateway that routes by model
    # answers "no backend for model probe" -- a 404 that says the path is fine and
    # only the name is wrong. Asking for a model the catalog lists removes that
    # false alarm and makes the status mean what it looks like it means.
    body = {
        "model": model_id,
        "messages": [{"role": "user", "content": "hi"}],
        "stream": False,
        "max_tokens": 1,
    }
    req = urllib.request.Request(
        base_url + "/chat/completions",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": "Bearer not-a-real-key",
            # Several of these sit behind gateways that 403 an unknown client
            # before looking at the key, which would hide the answer we want.
            "User-Agent": "curl/8.14.1",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            return resp.status, ""
    except urllib.error.HTTPError as e:
        try:
            snippet = e.read(160).decode("utf-8", "replace").replace("\n", " ")
        except Exception:
            snippet = ""
        return e.code, snippet
    except Exception as e:  # noqa: BLE001 - any transport failure is a status of 000
        return 0, type(e).__name__ + ": " + str(e)[:120]


def main():
    with open(gen.SNAPSHOT, encoding="utf-8") as fh:
        data = json.load(fh)
    providers, _ = gen.collect(data)

    wanted = sys.argv[1:]
    if wanted:
        providers = [p for p in providers if p["id"] in wanted]

    good, bad = [], []
    for p in providers:
        status, note = probe(p["base_url"], p["models"][0]["id"])
        # A local server that is not running reports 000; that is expected and
        # says nothing about whether the URL is right.
        verdict = "ok" if status in (400, 401, 403, 405, 422) else "CHECK"
        if status == 0 and p["base_url"].startswith("http://127.0.0.1"):
            verdict = "skip"
        (bad if verdict == "CHECK" else good).append(p["id"])
        print(f"  {verdict:5s} {status:3d}  {p['id']:18s} {p['base_url']}")
        if note:
            print(f"        {note}")

    print()
    print(f"  answered as an endpoint: {len(good)}")
    print(f"  worth a look:            {len(bad)}  {bad if bad else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
