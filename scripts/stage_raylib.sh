#!/usr/bin/env bash
# Build raylib with the JPG/TGA decoders required by original Quake II/III assets.
# Upstream's prebuilt raylib 6 libraries disable both formats by default.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR="$REPO_ROOT/vendor"
RAYLIB_VERSION="6.0"
ARCHIVE_SHA256="2b3ee1e2120c7a0796b33062c7e9a694dd8a8caa56a96319ac8c8ecf54a90d0b"
case "$(uname -s)" in
  Darwin) lib_glob="libraylib*.dylib" ;;
  Linux) lib_glob="libraylib.so*" ;;
  *) echo "Unsupported OS" >&2; exit 1 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
curl -fsSL "https://github.com/raysan5/raylib/archive/refs/tags/${RAYLIB_VERSION}.tar.gz" -o "$tmp/raylib.tar.gz"
if command -v sha256sum >/dev/null; then
  actual="$(sha256sum "$tmp/raylib.tar.gz" | cut -d ' ' -f 1)"
else
  actual="$(shasum -a 256 "$tmp/raylib.tar.gz" | cut -d ' ' -f 1)"
fi
if [[ "$actual" != "$ARCHIVE_SHA256" ]]; then
  echo "Raylib source checksum mismatch" >&2; exit 1
fi
tar -xzf "$tmp/raylib.tar.gz" -C "$tmp"
make -C "$tmp/raylib-${RAYLIB_VERSION}/src" -j4 \
  PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=SHARED \
  CUSTOM_CFLAGS="-DSUPPORT_FILEFORMAT_JPG=1 -DSUPPORT_FILEFORMAT_TGA=1"
mkdir -p "$VENDOR"
cp -P "$tmp/raylib-${RAYLIB_VERSION}/src/"$lib_glob "$VENDOR/"
echo "Staged raylib $RAYLIB_VERSION with JPG/TGA support in $VENDOR"
