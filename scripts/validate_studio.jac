"""Drive the studio in the real game and check what it did.

Runs `qp` (build it first, or pass --binary) on an active desktop with
scripts/studio/shell_session.cfg: the interface is clicked, typed into and
dragged by scripted input, the document is printed after each step, and
screenshots are taken along the way. A second run without the studio checks
that the saved entities are what the level loads.

    jac run scripts/validate_studio.jac [--binary ./qp]

Output: .jac/screenshots/studio/."""
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from scripts.png_checks { read_png }

"""The lines `ed_dump` printed after `echo STEP <name>`, by step."""
def studio_steps(text: str) -> dict[str, list[str]] {
    steps: dict[str, list[str]] = {"start": []};
    current = "start";
    for line in text.splitlines() {
        if line.startswith("studio: ") {
            steps[current].append(line[8:]);
        } elif line.startswith("STEP ") {
            current = line[5:].strip();
            steps[current] = [];
        }
    }
    return steps;
}

"""A capture of the default window (1280 by 720, or twice that on a dense
display) that is not blank."""
def check_capture(path: Path) {
    decoded = read_png(path);
    assert decoded.width in [1280, 2560] and decoded.height * 16 == decoded.width * 9 , str(path);
    colors: set[bytes] = set();
    for i in range(0, len(decoded.pixels), decoded.channels * 97) {
        colors.add(decoded.pixels[i:i + 3]);
    }
    assert len(colors) >= 65 , f"{path} is nearly blank ({len(colors)} colours)";
}

def selected(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("selected ")];
}

def main() {
    repo = Path(__file__).resolve().parent.parent;
    binary = repo / "qp";
    if "--binary" in sys.argv {
        binary = Path(sys.argv[sys.argv.index("--binary") + 1]).resolve();
    }
    assert binary.exists() , f"Build qp first: {binary} is missing";
    output = repo / ".jac/screenshots/studio";
    output.mkdir(parents=True, exist_ok=True);
    shots = ["open", "listed", "looked", "picked", "edited", "menu", "playing", "returned"];
    for shot in shots {
        (repo / f"studio_{shot}.png").unlink(missing_ok=True);
    }
    env = dict(os.environ);
    for key in ["DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"] {
        env[key] = str(repo / "vendor") + (os.pathsep + env[key] if env.get(key) else "");
    }
    env["QP_GAME"] = "q1";
    env["QP_MAP"] = "e1m1";
    with tempfile.TemporaryDirectory(prefix="qp-studio-") as home {
        # Fresh settings (the default window) and a place of its own to save.
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/shell_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "run.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The studio session failed: {output / 'run.log'}";
        saved = Path(home) / "overrides/q1/e1m1.ent";
        assert saved.exists() , "Save wrote no entity file";
        saved_text = saved.read_text();
        again = subprocess.run(
            [str(binary), "+edit", "+ed_select", "class:info_player_start", "+ed_dump", "+quit"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "reload.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"The reload failed: {output / 'reload.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "picked-from-list", "angle-set", "refused", "undone", "redone", "cleared", "picked-in-level", "dragged",
        "flown", "added", "nudged", "duplicated", "deleted", "saved", "returned"
    ] {
        assert name in steps and steps[name] , f"Step {name} printed nothing: {output / 'run.log'}";
    }
    start = steps["start"][0];
    assert start.startswith("q1/e1m1 entities=") and "dirty=0" in start , start;
    count = int(start.split("entities=")[1].split()[0]);

    picked = selected(steps["picked-from-list"]);
    assert len(picked) == 1 and "classname=info_player_start" in picked[0] , str(picked);
    assert "angle=90" in picked[0] , picked[0];
    assert "angle=180" in selected(steps["angle-set"])[0] and "dirty=1" in steps["angle-set"][0];
    refused = selected(steps["refused"])[0];
    assert "origin=480 -352 88" in refused and "angle=180" in refused and "undo=1" in steps["refused"][0];
    assert "angle=90" in selected(steps["undone"])[0] and "redo=1" in steps["undone"][0];
    assert "angle=180" in selected(steps["redone"])[0] and "redo=0" in steps["redone"][0];
    assert not selected(steps["cleared"]);
    level_pick = selected(steps["picked-in-level"]);
    assert len(level_pick) == 1 and "classname=info_player_start" in level_pick[0] , str(level_pick);
    # The left drag moved it as seen (the camera looks level, so sideways):
    # same height, somewhere else.
    dragged = selected(steps["dragged"]);
    assert len(dragged) == 1 and "origin=480 -352 88" not in dragged[0] , str(dragged);
    assert dragged[0].split("origin=")[1].split()[2] == "88" , dragged[0];
    # The right drag turned the camera and the wheel moved it.
    assert steps["flown"][1] != steps["dragged"][1] , "The camera did not move";
    added = selected(steps["added"]);
    assert len(added) == 1 and "classname=light" in added[0] and "origin=" in added[0] , str(added);
    assert f"entities={count + 1}" in steps["added"][0];
    nudged = selected(steps["nudged"]);
    assert len(nudged) == 1 and nudged[0] != added[0] and "classname=light" in nudged[0] , str(nudged);
    copied = selected(steps["duplicated"]);
    assert len(copied) == 1 and "classname=light" in copied[0] and copied[0] != nudged[0];
    assert f"entities={count + 2}" in steps["duplicated"][0];
    assert f"entities={count + 1}" in steps["deleted"][0] and not selected(steps["deleted"]);
    assert "dirty=0" in steps["saved"][0] , steps["saved"][0];
    assert f"entities={count + 1}" in steps["returned"][0] , steps["returned"][0];

    assert "\"angle\" \"180\"" in saved_text and saved_text.count("\"classname\" \"light\"") >= 1;
    reloaded = selected(studio_steps(again.stdout)["start"]);
    assert reloaded and "angle=180" in reloaded[0] , "The saved entities were not loaded: " + str(reloaded);

    for shot in shots {
        source = repo / f"studio_{shot}.png";
        check_capture(source);
        shutil.copyfile(source, output / f"{shot}.png");
        source.unlink();
    }
    print(f"STUDIO PASS: {len(steps) - 1} steps, {count} entities, saved and reloaded");
    print(f"Screenshots and logs: {output}");
}

with entry {
    main();
}
