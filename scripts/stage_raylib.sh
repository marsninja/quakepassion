#!/usr/bin/env bash
# Stage a precompiled raylib shared library into vendor/ for the native build.
#
# The .na.jac renderer/input bind raylib by its logical name via
# `import from vendor.raylib`, so the native linker records a
# `$ORIGIN/vendor/libraylib.so` DT_NEEDED — the loader resolves it beside the
# binary regardless of cwd. This script fetches the matching precompiled release
# (no build, no system install) and drops the .so set into vendor/, exactly the
# way the raylib_shooter demo stages its sibling library.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor"
RAYLIB_VERSION="6.0"
BASE_URL="https://github.com/raysan5/raylib/releases/download/${RAYLIB_VERSION}"

uname_s="$(uname -s)"
arch="$(uname -m)"
case "$uname_s" in
  Linux)
    case "$arch" in
      x86_64|amd64)  asset="raylib-${RAYLIB_VERSION}_linux_amd64.tar.gz" ;;
      aarch64|arm64) asset="raylib-${RAYLIB_VERSION}_linux_arm64.tar.gz" ;;
      *) echo "Unsupported Linux arch: $arch" >&2; exit 1 ;;
    esac
    lib_glob="libraylib.so*" ;;
  Darwin)
    asset="raylib-${RAYLIB_VERSION}_macos.tar.gz"
    lib_glob="libraylib*.dylib" ;;
  *) echo "Unsupported OS: $uname_s" >&2; exit 1 ;;
esac

mkdir -p "$VENDOR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "==> Downloading $asset"
curl -fsSL "$BASE_URL/$asset" -o "$tmp/raylib.tar.gz"
tar -xzf "$tmp/raylib.tar.gz" -C "$tmp"

lib_src_dir="$(dirname "$(find "$tmp" -name 'libraylib.so' -o -name 'libraylib.dylib' | head -n1)")"
# cp -P preserves the version symlinks (libraylib.so -> .so.600 -> .so.6.0.0)
cp -P "$lib_src_dir"/$lib_glob "$VENDOR/"
echo "==> Staged raylib $RAYLIB_VERSION -> $VENDOR/"
ls -la "$VENDOR"
