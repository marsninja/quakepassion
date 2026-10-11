#!/usr/bin/env bash
# Build QuakePassion for Windows, from Linux or macOS: dist/windows/qp.exe with
# the two DLLs it loads beside it. Copy the folder to a Windows machine and run
# qp.exe; nothing else needs installing there.
#
# The jac compiler writes the executable itself (no Windows toolchain); zig
# cross-builds raylib and zlib (scripts/stage_windows_libs.sh). JAC_DEV_SOURCE
# must point at the pinned compiler, as for any build (scripts/stage_compiler.sh).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"
if [[ ! -f vendor/windows/raylib.dll || ! -f vendor/windows/z.dll ]]; then
  ./scripts/stage_windows_libs.sh
fi
mkdir -p dist/windows
jac build main.jac --native --target-triple x86_64-pc-windows-msvc -o dist/windows/qp.exe
cp vendor/windows/raylib.dll vendor/windows/z.dll dist/windows/
echo "Built dist/windows: qp.exe, raylib.dll, z.dll"
