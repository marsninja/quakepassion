"""Validate native persistence and gameplay input without touching user saves."""
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from scripts.png_checks { check_image }

with entry {
    repo = Path(__file__).resolve().parent.parent;
    assets = Path.home() / "quake-assets";
    assert assets.is_dir(), "Place the original game assets in ~/quake-assets";
    output = repo / ".jac/screenshots/gameplay";
    output.mkdir(parents=True, exist_ok=True);
    env = dict(os.environ);
    for key in ["DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"] {
        env[key] = str(repo / "vendor")
            + (os.pathsep + env[key] if env.get(key) else "");
    }
    for suite in ["persistence", "gameplay", "campaign", "combat"] {
        binary = repo / (".jac/qp-acceptance-" + suite);
        built = subprocess.run(
            ["jac", "build", "scripts/" + suite + "_smoke.jac", "--native", "-o", str(binary)],
            cwd=repo, env=env, capture_output=True, text=True, timeout=300
        );
        (output / (suite + "-build.log")).write_text(built.stdout + built.stderr);
        assert built.returncode == 0, "Build failed: " + suite;
        captures: list[str] = [];
        if suite in ["persistence", "combat"] {
            captures = ["qp_" + suite + "_" + game + ".png" for game in ["q1", "q2", "q3"]];
        } elif suite == "gameplay" {
            captures = ["qp_gameplay_dead_" + game + ".png" for game in ["q1", "q2", "q3"]]
                + ["qp_gameplay_arena_won.png"];
        }
        for name in captures { (repo / name).unlink(missing_ok=True); }
        with tempfile.TemporaryDirectory(prefix="qp-acceptance-") as home {
            (Path(home) / "quake-assets").symlink_to(assets, target_is_directory=True);
            run_env = dict(env);
            run_env["HOME"] = home;
            run_env["QP_VALIDATE_HOME"] = home;
            ran = subprocess.run(
                [str(binary)], cwd=repo, env=run_env,
                capture_output=True, text=True, timeout=180
            );
            (output / (suite + "-run.log")).write_text(ran.stdout + ran.stderr);
            assert ran.returncode == 0, "Acceptance failed: " + suite;
            markers: list[str] = [];
            if suite == "campaign" { markers = ["HUB PASS:", "KEY ROUTE PASS:"]; }
            else {
                prefix = "PERSISTENCE PASS " if suite == "persistence" else
                    ("COMBAT PASS " if suite == "combat" else "GAMEPLAY INPUT PASS ");
                markers = [prefix + game for game in ["q1", "q2", "q3"]];
            }
            for marker in markers {
                assert marker in ran.stdout, "Missing result: " + marker;
                print(marker);
            }
            if suite == "persistence" {
                assert "PREFERENCES PASS" in ran.stdout;
                print("PREFERENCES PASS");
            }
        }
        for name in captures {
            check_image(repo / name);
            shutil.copyfile(repo / name, output / name);
        }
    }
    print("Acceptance logs and captures:", str(output));
}
