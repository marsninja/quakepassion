#!/usr/bin/env bash
# Stage the pinned jac compiler source in the jaseci submodule so the installed
# jac binary compiles with it (JAC_DEV_SOURCE). The submodule pins upstream
# fixes that no jac release carries yet. The launcher silently falls back to
# its bundled compiler unless the typeshed stdlib stubs are present, so this
# fetches the commit the compiler pins (jac's own `zig build fetch-typeshed`).
# Prints the environment to export. The first compile then builds the native
# compiler kernel from this source (long, once per pin and cache); add
# JAC_COMPILER_LIB=off to run the compiler interpreted instead.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$REPO_ROOT/jaseci/jac"
TYPESHED="$SOURCE/jaclang/vendor/typeshed"

git -C "$REPO_ROOT" submodule update --init jaseci >&2
commit="$(tr -d '[:space:]' < "$TYPESHED/PIN")"
expected="$(tr -d '[:space:]' < "$TYPESHED/TARBALL_SHA256")"
if [[ "$(cat "$TYPESHED/stdlib/.typeshed-sha" 2>/dev/null)" != "$commit" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # The pin is the checksum of the uncompressed tar.
  curl -fsSL "https://codeload.github.com/python/typeshed/tar.gz/$commit" | gunzip > "$tmp/typeshed.tar"
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$tmp/typeshed.tar" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$tmp/typeshed.tar" | cut -d ' ' -f 1)"
  fi
  if [[ "$actual" != "$expected" ]]; then
    echo "typeshed checksum mismatch" >&2; exit 1
  fi
  tar -xf "$tmp/typeshed.tar" -C "$tmp"
  rm -rf "$TYPESHED/stdlib"
  mv "$tmp/typeshed-$commit/stdlib" "$TYPESHED/stdlib"
  printf '%s\n' "$commit" > "$TYPESHED/stdlib/.typeshed-sha"
fi

echo "JAC_DEV_SOURCE=$SOURCE"
