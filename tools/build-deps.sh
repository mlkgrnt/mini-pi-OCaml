#!/usr/bin/env bash
#
# Build and install the OCaml dependencies of mini-pi-OCaml into the `mini-pi`
# opam switch -- without using opam.
#
# Why not `opam install`?
# -----------------------
# opam's action runner shells out to the Cygwin `tar` to unpack archives. In
# this sandboxed Windows environment that tar invocation produces an empty
# .out file and never spawns a child process, so `opam install` blocks forever
# at "Processing actions". This was reproduced with OPAMJOBS=1, with TMP/TEMP
# redirected to E:, and with the sandbox disabled -- all three hang. Unpacking
# the same archives with Python's `tarfile` works fine, so we unpack by hand and
# then drive `dune build` / `dune install` ourselves.
#
# Usage:  bash E:/ocaml/build-deps.sh <dir-with-unpacked-sources>
#
# Build order (each step depends on the previous ones):
#   dune              bootstraps itself; everything else needs it
#   cppo              lwt + ocplib-endian preprocess their sources with it
#   csexp             dune-configurator links against it
#   ocplib-endian     lwt.unix links ocplib-endian.bigstring
#   dune-configurator feature probing inside lwt (ships inside the dune tree)
#   lwt               the async runtime the port is written against
#   yojson            JSON; pure OCaml, no runtime dependencies
#
# Recorded traps -- all four cost real time:
#
#   1. `-p PKG` cannot be combined with `--root .`. In dune, `-p` expands to
#      `--release`, and `--release` already contains `--root .`, so the second
#      one makes dune abort with "option '--root' cannot be repeated".
#
#   2. A stale `_build/.lock`, left behind by any interrupted run, poisons every
#      later dune invocation with
#          Error: open(_build/.lock): Permission denied
#          Error: open(E:\ocaml\tmp/dune_*_output): Permission denied
#      It is NOT an ACL, read-only-attribute, file-lock or sandbox problem --
#      all four were ruled out experimentally, and a fresh _build always works.
#      Hence the unconditional `rm -rf _build` in build_pkg.
#
#   3. dune's `install` subcommand takes package names positionally, not via -p.
#
#   4. Do not trust `lwt.opam`'s top-level `depends` (it lists only dune, ocaml,
#      cppo). The real closure only shows up as one build error at a time, and
#      `dune-configurator` is the hidden one: it is not a downloadable tarball,
#      it lives at otherlibs/configurator inside dune's own source tree.
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$HERE/ocaml-env.sh"

DEPS="${1:-}"
if [ -z "$DEPS" ] || [ ! -d "$DEPS" ]; then
  echo "usage: bash $0 <dir-with-unpacked-sources>" >&2
  exit 2
fi
DEPS="$(cd "$DEPS" && pwd)"

PREFIX="E:/ocaml/opam/mini-pi"
PREFIX_UNIX="/e/ocaml/opam/mini-pi"
DUNE_SRC="$DEPS/dune-3.24.2"

say() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. dune
# ---------------------------------------------------------------------------
# `ocaml boot/bootstrap.ml` compiles all of dune's own modules with the
# bytecode compiler and links _boot/dune.exe. That executable is already a
# complete, working dune, so it can simply be installed.
bootstrap_dune() {
  say "dune: bootstrap"
  if [ ! -d "$DUNE_SRC" ]; then
    echo "missing source tree: $DUNE_SRC" >&2
    return 1
  fi
  cd "$DUNE_SRC" || return 1

  # The native compiler needs the mingw assembler on PATH (see ocaml-env.sh).
  if ! ocaml -version >/dev/null 2>&1; then
    echo "ocaml is not on PATH -- did ocaml-env.sh source correctly?" >&2
    return 1
  fi

  # Bootstrapping compiles ~1900 artefacts and takes ~12 min on this disk, so
  # reuse an existing _boot/dune.exe. Delete _boot to force a rebuild.
  if [ -x _boot/dune.exe ]; then
    echo "reusing existing _boot/dune.exe"
  else
    ocaml boot/bootstrap.ml || return 1
  fi
  [ -f _boot/dune.exe ] || { echo "bootstrap produced no _boot/dune.exe" >&2; return 1; }

  mkdir -p "$PREFIX_UNIX/bin"
  cp -f _boot/dune.exe "$PREFIX_UNIX/bin/dune.exe" || return 1
  echo "installed: dune $("$PREFIX_UNIX/bin/dune.exe" --version 2>&1)"
}

# ---------------------------------------------------------------------------
# 2. one dune-based package  (build, then install)
# ---------------------------------------------------------------------------
# build_pkg <source-subdir> <opam-package-name>
build_pkg() {
  local dir="$1" pkg="$2"
  say "$pkg  ($dir)"
  cd "$DEPS/$dir" || return 1

  # Always start clean; see trap 2 in the header.
  rm -rf _build

  # `-p PKG` restricts dune to a single opam package (trap 1: never add --root
  # alongside it). Without the restriction we would try to build unrelated
  # packages that need libraries we do not have: cppo_ocamlbuild (ocamlbuild),
  # yojson-bench (benchmark), yojson-five (sedlex), lwt_ppx, lwt_react.
  dune build -p "$pkg" @install || return 1

  # dune install has no -p (trap 3): explicit root + positional package name.
  dune install --root . "$pkg" --prefix "$PREFIX" || return 1
  echo "installed: $pkg"
}

# ---------------------------------------------------------------------------
# run
# ---------------------------------------------------------------------------
bootstrap_dune || { echo "FAILED: dune" >&2; exit 1; }
build_pkg cppo-1.8.0        cppo              || { echo "FAILED: cppo" >&2; exit 1; }
build_pkg csexp-1.5.2       csexp             || { echo "FAILED: csexp" >&2; exit 1; }
build_pkg ocplib-endian-1.2 ocplib-endian     || { echo "FAILED: ocplib-endian" >&2; exit 1; }
build_pkg dune-3.24.2       dune-configurator || { echo "FAILED: dune-configurator (trap 4)" >&2; exit 1; }
build_pkg lwt-6.1.2         lwt               || { echo "FAILED: lwt" >&2; exit 1; }
build_pkg yojson-3.0.0      yojson            || { echo "FAILED: yojson" >&2; exit 1; }

say "verifying"
missing=0
for p in cppo csexp ocplib-endian dune-configurator lwt yojson unix threads; do
  printf '  %-18s ' "$p"
  if ocamlfind query "$p" >/dev/null 2>&1; then
    ocamlfind query "$p"
  else
    echo "NOT FOUND"
    missing=1
  fi
done
[ "$missing" -eq 0 ] && say "all dependencies present" || { echo "SOME DEPS MISSING" >&2; exit 1; }
