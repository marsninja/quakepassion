#!/usr/bin/env python3
"""Apply the native compiler fixes to a private copy of the installed Jac compiler."""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, help="Jac repository checkout containing the upstream native ZIP fix (PR 9322)")
    parser.add_argument("--patch", type=Path, action="append", default=[], help="Additional upstream patch to apply to a --source checkout copy")
    args = parser.parse_args()
    if args.patch and not args.source:
        parser.error("--patch requires --source")
    repo = Path(__file__).resolve().parent.parent
    if args.source:
        source = args.source.resolve() / "jac/jaclang"
        if not (source / "runtime/na_stdlib/zipfile.jac").is_file():
            raise SystemExit("Source checkout does not contain the native zipfile module")
        destination = repo / ".jac/compiler"
        if destination.exists():
            raise SystemExit(f"Move {destination} aside before staging a different compiler")
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=args.source, text=True).strip()
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="compiler-", dir=destination.parent) as stage_dir:
            stage = Path(stage_dir)
            shutil.copytree(source, stage / "jaclang", ignore=shutil.ignore_patterns("__pycache__", ".jac"))
            (stage / "jaclang/_precompiled/MANIFEST.json").unlink(missing_ok=True)
            stubs = stage / "jaclang/vendor/typeshed"
            if not (stubs / "stdlib/builtins.pyi").is_file():
                probe = stage / "installed_location.jac"
                probe.write_text("import jaclang;\nwith entry { print(jaclang.__file__); }\n")
                env = {**os.environ, "JAC_NO_DEV_SOURCE": "1"}
                env.pop("JAC_DEV_SOURCE", None)
                env.pop("JAC_REBUILD", None)
                installed = Path(subprocess.check_output(["jac", "run", str(probe)],
                    cwd=repo, env=env, text=True).strip().splitlines()[-1]).parent
                bundled_stubs = installed / "vendor/typeshed"
                if (stubs / "PIN").read_text() != (bundled_stubs / "PIN").read_text():
                    raise SystemExit("Typeshed revisions differ; run zig build fetch-typeshed in the source checkout's jac directory")
                shutil.copytree(bundled_stubs / "stdlib", stubs / "stdlib")
                probe.unlink()
            for patch in args.patch:
                subprocess.run(["patch", "--batch", "-p1", "-i", str(patch.resolve())], cwd=stage, check=True)
            (stage / ".quakepassion-source").write_text(revision + "\n")
            if args.patch:
                (stage / ".quakepassion-extra-patches").write_text(
                    "".join(f"{p.name} {hashlib.sha256(p.read_bytes()).hexdigest()}\n" for p in args.patch))
            stage.rename(destination)
        print(f"Staged upstream compiler {revision}. Use JAC_COMPILER_LIB=off with the local jac binary.")
        return
    patches = [
        repo / "patches/jac-0.37.19-native-visit.patch",
        repo / "patches/jac-0.37.19-native-assets.patch",
    ]
    destination = repo / ".jac/compiler"
    marker = destination / ".quakepassion-patch"
    digest = hashlib.sha256(b"".join(p.read_bytes() for p in patches)).hexdigest()
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
        for patch in patches:
            subprocess.run(
                ["patch", "--batch", "-p1", "-i", str(patch)], cwd=stage, check=True
            )
        (stage / marker.name).write_text(digest + "\n")
        stage.rename(destination)
    print(f"Patched compiler prepared: {destination}")
    print("Run jac run main.jac. The first source compilation may take a few minutes.")


if __name__ == "__main__":
    main()
