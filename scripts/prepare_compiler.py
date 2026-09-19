#!/usr/bin/env python3
"""Apply the native visit fix to a private copy of the installed Jac compiler."""

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parent.parent
    patch = repo / "patches/jac-0.37.19-native-visit.patch"
    destination = repo / ".jac/compiler"
    marker = destination / ".quakepassion-patch"
    digest = hashlib.sha256(patch.read_bytes()).hexdigest()
    env = {**os.environ, "JAC_NO_DEV_SOURCE": "1"}
    env.pop("JAC_DEV_SOURCE", None)
    env.pop("JAC_REBUILD", None)
    version = subprocess.check_output(["jac", "--version"], env=env, text=True)
    if not version.startswith("jac 0.37.19 "):
        raise SystemExit("This patch targets Jac 0.37.19. Retest the repro before adapting it to another version.")
    if marker.is_file() and marker.read_text().strip() == digest:
        print(f"Patched compiler already prepared: {destination}")
        return
    if destination.exists():
        raise SystemExit(f"Refusing to overwrite {destination}; move it aside before preparing a new compiler.")

    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="qp-compiler-") as probe_dir:
        probe = Path(probe_dir) / "location.jac"
        probe.write_text("import jaclang;\nwith entry { print(jaclang.__file__); }\n")
        output = subprocess.check_output(
            ["jac", "run", str(probe)], cwd=repo, env=env, text=True
        )
        source = Path(output.strip().splitlines()[-1]).parent
        if source.name != "jaclang" or not (source / "__init__.py").is_file():
            raise SystemExit(f"Could not locate the installed compiler: {output}")

    # Stage on the same filesystem; publish only after the patch applies cleanly.
    with tempfile.TemporaryDirectory(prefix="compiler-", dir=destination.parent) as stage_dir:
        stage = Path(stage_dir)
        shutil.copytree(source, stage / "jaclang", ignore=shutil.ignore_patterns("__pycache__"))
        # A sealed manifest makes Jac execute the original bundled bytecode.
        # This private copy must compile the patched source instead.
        (stage / "jaclang/_precompiled/MANIFEST.json").unlink(missing_ok=True)
        subprocess.run(
            ["patch", "--batch", "-p1", "-i", str(patch)], cwd=stage, check=True
        )
        (stage / marker.name).write_text(digest + "\n")
        stage.rename(destination)
    print(f"Patched compiler prepared: {destination}")
    print("Run jac run main.jac. The first source compilation may take a few minutes.")


if __name__ == "__main__":
    main()
