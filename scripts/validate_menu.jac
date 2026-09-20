"""Build and exercise the native Escape menu on an active graphical desktop."""
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from scripts.png_checks { check_image }

def main() {
    repo = Path(__file__).resolve().parent.parent;
    output = repo / ".jac/screenshots/menu";
    output.mkdir(parents=True, exist_ok=True);
    binary = repo / ".jac/qp-menu-test";
    env = dict(os.environ);
    subprocess.run(
        ["jac", "build", "scripts/menu_smoke.jac", "--native", "-o", str(binary)],
        cwd=repo,
        env=env,
        check=True,
        timeout=300
    );
    for key in ["DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"] {
        env[key] = str(repo / "vendor")
            + (os.pathsep + env[key] if env.get(key) else "");
    }
    suffixes = ["settings", "q1", "q2", "q3", "loaded_q2", "loaded_q3", "return_q1"];
    for suffix in suffixes {
        (repo / f"qp_menu_{suffix}.png").unlink(missing_ok=True);
    }
    for game in ["q1", "q2", "q3"] {
        (repo / f"qp_walk_{game}.png").unlink(missing_ok=True);
    }
    ran = subprocess.run(
        [str(binary)], cwd=repo, env=env, capture_output=True, text=True, timeout=180
    );
    (output / "run.log").write_text(ran.stdout + ran.stderr);
    assert ran.returncode == 0 , f"Menu validation failed: {output / 'run.log'}";
    assert "MENU PASS:" in ran.stdout , "Menu sequence did not complete";
    for suffix in suffixes {
        source = repo / f"qp_menu_{suffix}.png";
        check_image(source);
        shutil.copyfile(source, output / f"{suffix}.png");
    }
    for game in ["q1", "q2", "q3"] {
        source = repo / f"qp_walk_{game}.png";
        check_image(source);
        shutil.copyfile(source, output / f"walk_{game}.png");
    }
    for line in ran.stdout.splitlines() {
        if line.startswith("MENU PASS:") {
            print(line);
        }
    }
    print(f"Screenshots and log: {output}");
}

with entry {
    main();
}
