"""Run graphical map checks against local assets without bundling them."""
import argparse;
import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from scripts.png_checks { PngImage, check_image, different_pixels }

def main() {
    parser = argparse.ArgumentParser(
        description="Validate native Quake rendering and visibility"
    );
    parser.add_argument("maps", nargs="*", `default=[]);
    parser.add_argument("--binary", `default="qp");
    parser.add_argument("--game", choices=["q1", "q2", "q3"], `default="q1");
    args = parser.parse_args();
    maps: list[str] = args.maps;
    if not maps {
        defaults = {
            "q1": ["e1m1", "start", "e1m2", "e2m1", "e3m1", "e4m1"],
            "q2": ["base1", "base2", "base3"],
            "q3": ["q3dm1", "q3dm7", "q3tourney2"]
        };
        maps = defaults[args.game];
    }
    repo = Path(__file__).resolve().parent.parent;
    binary = (repo / args.binary).resolve();
    output = repo / ".jac/screenshots" / args.game;
    for name in maps {
        assert name and all(c.isalnum() or c in "_-" for c in name) , "Use a map basename";
        destination = output / name;
        destination.mkdir(parents=True, exist_ok=True);
        env = dict(os.environ);
        env.update({"QP_SMOKE": "1", "QP_MAP": name, "QP_GAME": args.game});
        env.pop("QP_GRAYBOX", None);
        suffixes = ["pvs", "all", "turn", "moved_pvs", "moved_all"];
        for suffix in suffixes {
            (repo / f"qp_quake_{suffix}.png").unlink(missing_ok=True);
        }
        proc = subprocess.run(
            [str(binary)],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=180
        );
        (destination / "run.log").write_text(proc.stdout + proc.stderr);
        assert proc.returncode == 0 , f"{name} failed; see {destination / 'run.log'}";
        images: dict[str, PngImage] = {};
        for suffix in suffixes {
            source = repo / f"qp_quake_{suffix}.png";
            images[suffix] = check_image(source);
            shutil.copyfile(source, destination / f"{suffix}.png");
        }
        for prefix in ["", "moved_"] {
            changed = different_pixels(images[prefix + "pvs"], images[prefix + "all"]);
            assert changed <= 16 , f"{name}: {changed} PVS pixel differences at {prefix
                or 'spawn'}";
            print(
                f"  {name} {prefix or 'spawn'}: {changed} / 921600 pixels differ",
                flush=True
            );
        }
        assert different_pixels(images["pvs"], images["turn"]) > 0 , f"{name}: camera turn had no effect";
        assert different_pixels(images["pvs"], images["moved_pvs"]) > 0 , f"{name}: flight had no effect";
        print(
            name
                + ": textured frames, camera movement, and PVS on/off comparison passed",
            flush=True
        );
        for line in proc.stdout.splitlines() {
            if line.startswith(("PVS ", "ALL ", "MOVED ")) {
                print("  " + line, flush=True);
            }
        }
    }
}

with entry {
    main();
}
