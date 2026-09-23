"""Build and validate Passion on an active desktop with isolated save files."""
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from scripts.png_checks { check_image, read_png }
with entry {
    repo = Path(__file__).resolve().parent.parent;
    assets = Path.home() / "quake-assets";
    assert assets.is_dir() , "Install all three game assets under ~/quake-assets";
    output = repo / ".jac/screenshots/passion";
    output.mkdir(parents=True, exist_ok=True);
    env = dict(os.environ);
    for key in ["DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"] {
        env[key] = str(repo / "vendor");
    }
    binary = repo / ".jac/qp-passion";
    built = subprocess.run(
        ["jac", "build", "scripts/passion_smoke.jac", "--native", "-o", str(binary)],
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=300
    );
    (output / "build.log").write_text(built.stdout + built.stderr);
    assert built.returncode == 0 , "Passion build failed; see build.log";
    names = [
        "qp_passion.png",
        "qp_passion_menu.png",
        "qp_passion_complete.png",
        "qp_passion_vertical.png",
        "qp_passion_wall.png",
        "qp_passion_flash.png"
    ]
        + ["qp_passion_theme_" + str(i) + ".png" for i in range(4)];
    for name in names {
        (repo / name).unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-passion-") as home {
        (Path(home) / "quake-assets").symlink_to(assets, target_is_directory=True);
        env["HOME"] = home;
        env["QP_VALIDATE_HOME"] = home;
        ran = subprocess.run(
            [str(binary)],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=900
        );
        (output / "run.log").write_text(ran.stdout + ran.stderr);
        (output / ("run-" + env.get("QP_SEED", "42") + ".log")).write_text(
            ran.stdout + ran.stderr
        );
        assert ran.returncode == 0 and "PASSION PASS:" in ran.stdout , "Passion acceptance failed; see run.log";
        for line in ran.stdout.splitlines() {
            if line.startswith("PASSION") {
                print(line);
            }
        }
    }
    # Expeditions show two to four districts; only captured themes are checked.
    names = [
        name
        for name in names
        if (repo / name).exists() or "theme" not in name
    ];
    for name in names {
        # Flat menu panels/text have fewer colors than textured world geometry.
        check_image(
            repo / name, minimum_colors=8 if name == "qp_passion_menu.png" else 65
        );
        shutil.copyfile(repo / name, output / name);
    }
    normal = read_png(output / "qp_passion_wall.png");
    flashed = read_png(output / "qp_passion_flash.png");
    assert normal.width == flashed.width and normal.height == flashed.height;
    # Exclude the HUD/weapon; a flash must alter the rendered scene itself.
    brighter = 0;
    for y in range(normal.height // 2) {
        for x in range(normal.width) {
            a = (y * normal.width + x) * normal.channels;
            b = (y * flashed.width + x) * flashed.channels;
            if sum(flashed.pixels[b:b + 3]) > sum(normal.pixels[a:a + 3]) + 6 {
                brighter += 1;
            }
        }
    }
    assert brighter > 100 , "Combat flash did not illuminate world/model geometry";
    print("Passion flash brightened scene pixels:", brighter);
    print("Passion evidence:", str(output));
}
