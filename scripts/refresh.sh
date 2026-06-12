#!/usr/bin/env bash
# Refresh the jaseci submodule to upstream main and ensure an editable
# install of jaclang (jaseci/jac) exists in .venv.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBMODULE_DIR="$REPO_ROOT/jaseci"
JAC_DIR="$SUBMODULE_DIR/jac"
VENV_DIR="$REPO_ROOT/.venv"
PYTHON="${PYTHON:-python3}"

echo "==> Syncing jaseci submodule with upstream main"
git -C "$REPO_ROOT" submodule update --init --recursive jaseci
before_sha="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
git -C "$REPO_ROOT" submodule update --remote jaseci
git -C "$REPO_ROOT" submodule update --init --recursive jaseci
after_sha="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"

if [ "$before_sha" = "$after_sha" ]; then
    echo "    jaseci already at upstream main ($after_sha)"
else
    echo "    jaseci updated: $before_sha -> $after_sha"
    echo "    note: commit the submodule bump to record the new pin"
fi

echo "==> Ensuring virtualenv at .venv"
if [ ! -x "$VENV_DIR/bin/python" ]; then
    "$PYTHON" -m venv "$VENV_DIR"
    echo "    created $VENV_DIR"
else
    echo "    $VENV_DIR exists"
fi

echo "==> Ensuring editable install of jaclang from jaseci/jac"
editable_path="$({ "$VENV_DIR/bin/pip" show jaclang 2>/dev/null || true; } \
    | sed -n 's/^Editable project location: //p')"

if [ "$editable_path" = "$JAC_DIR" ] && [ "$before_sha" = "$after_sha" ]; then
    echo "    jaclang already installed editable from $JAC_DIR"
else
    "$VENV_DIR/bin/pip" install --editable "$JAC_DIR"
fi

echo "==> Ensuring editable installs of jac plugins (client, scale, super)"
for plugin in jac-client jac-scale jac-super; do
    pkg_name="$(echo "$plugin" | tr '-' '_')"
    if [ -e "$VENV_DIR/lib/python"*"/site-packages/$pkg_name" ] && [ "$before_sha" = "$after_sha" ]; then
        echo "    $plugin already installed"
    else
        (cd "$SUBMODULE_DIR" && "$VENV_DIR/bin/jac" install -e "$plugin")
    fi
done

echo "==> Done. jac version: $("$VENV_DIR/bin/jac" --version 2>/dev/null || echo 'n/a')"
