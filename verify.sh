#!/usr/bin/env bash
# Build and verify the OCaml port end to end.
#
#   ./verify.sh            build + run every check
#   ./verify.sh build      build only
#   ./verify.sh test       OCaml test suite only
#   ./verify.sh rpc        RPC protocol conformance only
#   ./verify.sh tui        TypeScript TUI client against the OCaml backend
#
# Requires the toolchain environment (see E:/ocaml/ocaml-env.sh for why that
# file is not optional on this machine).

set -u
# Needed for do_test: without it the exit status of `dune runtest | tail` is
# tail's, so a failing suite would still look green.
set -o pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SH="${MINI_PI_OCAML_ENV:-E:/ocaml/ocaml-env.sh}"

if [ ! -f "$ENV_SH" ]; then
  echo "missing $ENV_SH" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$ENV_SH"

cd "$ROOT" || exit 2

BIN="_build/default/bin/main.exe"
PY="C:/Users/Ashley Wilkes/AppData/Local/Programs/Python/Python312/python.exe"

step() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

do_build() {
  step "dune build"
  if ! dune build 2>&1; then
    echo "BUILD FAILED" >&2
    return 1
  fi
  echo "build ok -> $BIN"
}

do_test() {
  step "OCaml verification suite"
  dune runtest --force 2>&1 | tail -120
}

do_rpc() {
  step "RPC protocol conformance"
  node test/rpc_smoke.mjs "$BIN"
}

do_tui() {
  step "TypeScript TUI client -> OCaml backend"
  if [ ! -f tui/dist/rpc_client.js ]; then
    ( cd tui && ./node_modules/.bin/tsc ) || return 1
  fi
  node test/tui_client_check.mjs "$BIN"
}

case "${1:-all}" in
  build) do_build ;;
  test)  do_test ;;
  rpc)   do_rpc ;;
  tui)   do_tui ;;
  all)
    # Every step propagates its exit status: a check that fails but is not
    # allowed to fail the run is worse than no check, because it still reads as
    # a green result in CI and in a transcript.
    #
    # Each step also reports its own status, because "the run failed" without
    # saying which stage failed is the least useful possible message -- and
    # because a suite that prints ALL CHECKS PASSED and still exits non-zero is
    # a real thing that has happened here.
    fail=0
    run_step() {
      local name="$1"
      shift
      "$@"
      local rc=$?
      if [ "$rc" -eq 0 ]; then
        printf '[%s] ok\n' "$name"
      else
        printf '[%s] FAILED (exit %s)\n' "$name" "$rc" >&2
        fail=1
      fi
    }
    run_step build do_build
    [ "$fail" -eq 0 ] || exit 1
    run_step test do_test
    run_step rpc  do_rpc
    run_step tui  do_tui
    if [ "$fail" -ne 0 ]; then
      echo "VERIFICATION FAILED" >&2
      exit 1
    fi
    ;;
  ref)
    step "regenerate the wire-format reference from the Python original"
    ( cd "${MINI_PI_PY_SRC:-E:/mini-pi-src}" && "$PY" "$ROOT/tools/dump_wire_json.py" ) \
      > "$ROOT/tools/wire_json_reference.txt" && echo "wrote tools/wire_json_reference.txt"
    ;;
  *) echo "unknown step: $1" >&2; exit 2 ;;
esac
