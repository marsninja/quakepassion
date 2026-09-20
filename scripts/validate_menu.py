#!/usr/bin/env python3
"""Build and exercise the native Escape menu on an active graphical desktop."""
import os
from pathlib import Path
import shutil
import subprocess


def main():
    repo = Path(__file__).resolve().parent.parent
    output = repo / ".jac/screenshots/menu"
    output.mkdir(parents=True, exist_ok=True)
    binary = repo / ".jac/qp-menu-test"
    env = {**os.environ, "JAC_COMPILER_LIB": "off"}
    subprocess.run(
        ["jac", "build", "scripts/validate_menu.jac", "--native", "-o", str(binary)],
        cwd=repo, env=env, check=True, timeout=300,
    )
    for key in ("DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"):
        env[key] = str(repo / "vendor") + (os.pathsep + env[key] if env.get(key) else "")
    suffixes = ["q1", "q2", "q3", "loaded_q2", "loaded_q3", "return_q1"]
    for suffix in suffixes:
        (repo / f"qp_menu_{suffix}.png").unlink(missing_ok=True)
    ran = subprocess.run([str(binary)], cwd=repo, env=env, capture_output=True, text=True, timeout=180)
    (output / "run.log").write_text(ran.stdout + ran.stderr)
    assert ran.returncode == 0, f"Menu validation failed: {output / 'run.log'}"
    assert "MENU PASS:" in ran.stdout, "Menu sequence did not complete"
    for suffix in suffixes:
        shutil.copyfile(repo / f"qp_menu_{suffix}.png", output / f"{suffix}.png")
    print(next(line for line in ran.stdout.splitlines() if line.startswith("MENU PASS:")))
    print(f"Screenshots and log: {output}")


if __name__ == "__main__":
    main()
