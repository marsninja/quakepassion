#!/usr/bin/env bash
# Stage a user-owned Quake pak archive (pak0.pak, and pak1.pak if present)
# into id1/ for the engine to load.
#
# The original Quake .pak files are commercial id Software data and are NOT
# redistributable, so this script DOES NOT DOWNLOAD ANYTHING. You point it at a
# copy you legally own:
#   - retail Quake (Steam/GOG/CD) — its "id1" folder, or
#   - the freely-distributed Quake shareware pak0.pak (contains E1M1).
#
# Staged paks live in id1/ which is gitignored (never committed), exactly the
# way scripts/stage_raylib.sh stages the sibling raylib library into vendor/.
#
# Usage:
#   scripts/stage_id1.sh <path>
#     <path> = a directory containing pak0.pak (your Quake "id1" folder)
#              OR a path to a pak0.pak file directly.
#   (or set QUAKE_ID1=<path> instead of passing an argument)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/id1"

SRC="${1:-${QUAKE_ID1:-}}"
if [ -z "$SRC" ]; then
  echo "usage: $0 <path-to-id1-dir-or-pak0.pak>   (or set QUAKE_ID1)" >&2
  echo "Point it at a Quake copy you own — nothing is downloaded." >&2
  exit 2
fi

if [ -d "$SRC" ]; then
  src_dir="$SRC"
elif [ -f "$SRC" ]; then
  src_dir="$(cd "$(dirname "$SRC")" && pwd)"
else
  echo "Not found: $SRC" >&2
  exit 1
fi

# A valid PAK begins with the 4-byte magic "PACK".
is_pak() {
  [ -f "$1" ] && [ "$(head -c 4 "$1" 2>/dev/null)" = "PACK" ]
}

mkdir -p "$DEST"
declare -A seen
staged=0
for name in pak0.pak PAK0.PAK pak1.pak PAK1.PAK; do
  lc="$(printf '%s' "$name" | tr 'A-Z' 'a-z')"
  [ -n "${seen[$lc]:-}" ] && continue
  cand="$src_dir/$name"
  if [ -f "$cand" ]; then
    if is_pak "$cand"; then
      cp "$cand" "$DEST/$lc"
      seen[$lc]=1
      staged=$((staged + 1))
      echo "  staged $lc ($(du -h "$cand" | cut -f1), PACK magic ok)"
    else
      echo "  skipped $name: missing/invalid PACK magic" >&2
    fi
  fi
done

if [ "$staged" -eq 0 ]; then
  echo "No pak0.pak / pak1.pak found in $src_dir" >&2
  exit 1
fi
echo "==> Staged $staged pak(s) into $DEST (gitignored, not committed)"
ls -la "$DEST"
