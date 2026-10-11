#!/usr/bin/env bash
# Cross-build the two libraries a Windows qp.exe loads, from Linux or macOS,
# with zig as the C compiler: vendor/windows/raylib.dll and vendor/windows/z.dll,
# which ship beside the executable.
#
# z.dll is zlib, which the engine's zip and gzip reading calls: a Linux or
# macOS build links it into the executable, and a Windows build imports it.
#
# raylib.dll is the library stage_raylib.sh builds (JPG and TGA decoders on,
# qpDepthFunc and qpReadDepth added), with one change for Windows: no gamepads.
#
# GLFW sets up its joystick layer the first time any joystick call is made,
# and raylib makes one while it opens the window. On Windows that enumerates
# DirectInput devices, and one misbehaving device makes it wait a minute before
# the window appears (raysan5/raylib#1554). QuakePassion reads no gamepad, so
# the build leaves raylib's gamepad slots at zero and never makes the call.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/vendor/windows"
RAYLIB_VERSION="6.0"
ARCHIVE_SHA256="2b3ee1e2120c7a0796b33062c7e9a694dd8a8caa56a96319ac8c8ecf54a90d0b"
ZLIB_VERSION="1.3.1"
ZLIB_SHA256="9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
command -v zig >/dev/null || { echo "zig is required (https://ziglang.org/download/)" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# fetch <url> <sha256> <file>: download a source archive and check it.
fetch() {
  curl -fsSL "$1" -o "$3"
  local actual
  if command -v sha256sum >/dev/null; then
    actual="$(sha256sum "$3" | cut -d ' ' -f 1)"
  else
    actual="$(shasum -a 256 "$3" | cut -d ' ' -f 1)"
  fi
  if [[ "$actual" != "$2" ]]; then
    echo "Source checksum mismatch for $1" >&2; exit 1
  fi
}

fetch "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz" "$ZLIB_SHA256" "$tmp/zlib.tar.gz"
tar -xzf "$tmp/zlib.tar.gz" -C "$tmp"
(cd "$tmp/zlib-${ZLIB_VERSION}" && zig cc -target x86_64-windows-gnu -shared -O2 -o z.dll \
  -DZLIB_DLL -Wno-everything \
  adler32.c compress.c crc32.c deflate.c infback.c inffast.c inflate.c inftrees.c trees.c uncompr.c zutil.c)

fetch "https://github.com/raysan5/raylib/archive/refs/tags/${RAYLIB_VERSION}.tar.gz" "$ARCHIVE_SHA256" "$tmp/raylib.tar.gz"
tar -xzf "$tmp/raylib.tar.gz" -C "$tmp"
src="$tmp/raylib-${RAYLIB_VERSION}/src"

# The GL additions are the ones stage_raylib.sh appends: one copy, taken from it.
awk "/<<'ADDITIONS'/{on=1; next} /^ADDITIONS\$/{on=0} on" "$REPO_ROOT/scripts/stage_raylib.sh" >> "$src/rcore.c"
grep -q "qpReadDepth" "$src/rcore.c" || { echo "stage_raylib.sh no longer carries the GL additions" >&2; exit 1; }

# No joystick layer: see the header.
sed -i.bak '/glfwSetJoystickCallback(/d' "$src/platforms/rcore_desktop_glfw.c"

(cd "$src" && zig cc -target x86_64-windows-gnu -shared -O2 -o raylib.dll \
  -DPLATFORM_DESKTOP -DPLATFORM_DESKTOP_GLFW -DGRAPHICS_API_OPENGL_33 -D_GLFW_WIN32 \
  -DBUILD_LIBTYPE_SHARED -DSUPPORT_FILEFORMAT_JPG=1 -DSUPPORT_FILEFORMAT_TGA=1 \
  -DMAX_GAMEPADS=0 \
  -I. -Iexternal/glfw/include -Wno-everything \
  rcore.c rshapes.c rtextures.c rtext.c rmodels.c raudio.c rglfw.c \
  -lopengl32 -lgdi32 -lwinmm -lshell32 -luser32)
mkdir -p "$OUT"
cp "$src/raylib.dll" "$tmp/zlib-${ZLIB_VERSION}/z.dll" "$OUT/"
echo "Staged raylib $RAYLIB_VERSION and zlib $ZLIB_VERSION for Windows in $OUT"
