#!/usr/bin/env bash
# Build raylib with the JPG/TGA decoders required by original Quake II/III assets.
# Upstream's prebuilt raylib 6 libraries disable both formats by default.
# rlgl has no call for the depth comparison, which Quake III shader stages set
# (depthFunc equal), nor one to read the depth buffer, which Quake III's light
# flares are tested against, so the build also exports qpDepthFunc and
# qpReadDepth.
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
# rcore.c compiles rlgl and the GL loader, so GL calls resolve there.
cat >> "$tmp/raylib-${RAYLIB_VERSION}/src/rcore.c" <<'ADDITIONS'

// QuakePassion: GL state that rlgl does not expose.

// Set the depth comparison (GL_LEQUAL is rlgl's own; GL_EQUAL for depthFunc equal)
RLAPI void qpDepthFunc(int func)
{
    glDepthFunc((GLenum)func);
}

// Read the depth buffer (0 near, 1 far) at a point of the current viewport,
// given in normalized device coordinates (-1 to 1 each way)
RLAPI float qpReadDepth(float x, float y)
{
    GLint viewport[4] = { 0 };
    float depth = 1.0f;
    glGetIntegerv(GL_VIEWPORT, viewport);
    int column = (int)(0.5f*(1.0f + x)*(float)viewport[2]);
    int row = (int)(0.5f*(1.0f + y)*(float)viewport[3]);
    if (column < 0) column = 0;
    if (row < 0) row = 0;
    if (column >= viewport[2]) column = viewport[2] - 1;
    if (row >= viewport[3]) row = viewport[3] - 1;
    glReadPixels(viewport[0] + column, viewport[1] + row, 1, 1, GL_DEPTH_COMPONENT, GL_FLOAT, &depth);
    return depth;
}
ADDITIONS
make -C "$tmp/raylib-${RAYLIB_VERSION}/src" -j4 \
  PLATFORM=PLATFORM_DESKTOP RAYLIB_LIBTYPE=SHARED \
  CUSTOM_CFLAGS="-DSUPPORT_FILEFORMAT_JPG=1 -DSUPPORT_FILEFORMAT_TGA=1"
mkdir -p "$VENDOR"
cp -P "$tmp/raylib-${RAYLIB_VERSION}/src/"$lib_glob "$VENDOR/"
echo "Staged raylib $RAYLIB_VERSION with JPG/TGA support in $VENDOR"
