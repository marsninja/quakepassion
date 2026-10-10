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
def check_capture(path: Path, colours: int = 65) {
    decoded = read_png(path);
    assert decoded.width in [1280, 2560] and decoded.height * 16 == decoded.width * 9 , str(path);
    colors: set[bytes] = set();
    for i in range(0, len(decoded.pixels), decoded.channels * 97) {
        colors.add(decoded.pixels[i:i + 3]);
    }
    assert len(colors) >= colours , f"{path} is nearly blank ({len(colors)} colours)";
}

def selected(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("selected ")];
}

"""A brush's box from its `brush #` line: [low, high] as number lists."""
def brush_box(line: str) -> list[list[int]] {
    low = line.split("low=")[1].split()[0].split(",");
    high = line.split("high=")[1].split()[0].split(",");
    return [[int(part) for part in low], [int(part) for part in high]];
}

"""The line counting the document's brushes and its builds."""
def tally(lines: list[str]) -> str {
    found = [line for line in lines if line.startswith("brushes=")];
    return found[0] if found else "";
}

def brushes(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("brush #")];
}

"""The second session: a scene of brushes made, shaped, saved, reopened and
played."""
def scene_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["new", "picked", "edited", "playing", "returned"];
    for shot in shots {
        (repo / f"scene_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-scene-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/scene_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "scene.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The scene session failed: {output / 'scene.log'}";
        saved = Path(home) / "scenes/yard.map";
        assert saved.exists() , "Saving the scene wrote no map";
        saved_text = saved.read_text();
        again = subprocess.run(
            [
                str(binary), "+edit", "+ed_open", str(saved), "+ed_select", "class:brushes", "+ed_dump",
                "reopened", "+quit"
            ],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "scene_reopen.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Reopening the scene failed: {output / 'scene_reopen.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "opened", "boxed", "cleared", "picked", "resized", "moved", "painted", "tied", "untied", "retied",
        "copied", "saved", "returned"
    ] {
        assert name in steps and steps[name] , f"Step {name} printed nothing: {output / 'scene.log'}";
    }
    assert steps["opened"][0].startswith("passion/studio:yard entities=2") , steps["opened"][0];
    assert tally(steps["opened"]) == "brushes=1 geometry=0 built=0" , str(steps["opened"]);
    # The box lands on the floor, and the level is rebuilt with it.
    boxed = brush_box(brushes(steps["boxed"])[0]);
    assert boxed[0][2] == 0 and boxed[1][2] == 96 and boxed[1][0] - boxed[0][0] == 128 , str(boxed);
    assert tally(steps["boxed"]) == "brushes=2 geometry=1 built=1" , str(steps["boxed"]);
    assert not brushes(steps["cleared"]);
    picked = brushes(steps["picked"]);
    assert len(picked) == 1 and brush_box(picked[0]) == boxed , str(picked);
    # The top handle went up: taller, on the grid, nothing else moved.
    resized = brush_box(brushes(steps["resized"])[0]);
    assert resized[1][2] > 96 and resized[1][2] % 8 == 0 , str(resized);
    assert resized[0] == boxed[0] and resized[1][:2] == boxed[1][:2] , str(resized);
    # The brush went sideways: same size, somewhere else along x, on the grid.
    moved = brush_box(brushes(steps["moved"])[0]);
    assert moved[0][0] != resized[0][0] and (moved[0][0] - resized[0][0]) % 8 == 0 , str(moved);
    assert moved[1][0] - moved[0][0] == 128 and moved[0][1:] == resized[0][1:] , str(moved);
    assert "material=brick" in brushes(steps["painted"])[0];
    assert "owner=func_door" in brushes(steps["tied"])[0] and "entities=3" in steps["tied"][0];
    assert "owner=worldspawn" in brushes(steps["untied"])[0] and "entities=2" in steps["untied"][0];
    assert "owner=func_door" in brushes(steps["retied"])[0] and "entities=3" in steps["retied"][0];
    assert "brushes=4" in tally(steps["copied"]) and len(brushes(steps["copied"])) == 1 , str(steps["copied"]);
    assert "dirty=0" in steps["saved"][0];
    # Every geometry edit was followed by a rebuild.
    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert "brushes=4" in built and "entities=3" in steps["returned"][0];

    assert saved_text.startswith("// Format: Valve") and saved_text.count("// brush") == 4;
    assert "\"classname\" \"func_door\"" in saved_text and " brick [" in saved_text;
    reopened = studio_steps(again.stdout)["reopened"];
    assert reopened[0].startswith("passion/studio:yard entities=3") , reopened[0];
    assert "brushes=4" in tally(reopened) and len(brushes(reopened)) == 4 , str(reopened);
    # The door's brush came back where it was left, with its material.
    kept = [line for line in brushes(reopened) if "owner=func_door" in line];
    assert len(kept) == 1 and brush_box(kept[0]) == moved and "material=brick" in kept[0] , str(kept);
    for shot in shots {
        source = repo / f"scene_{shot}.png";
        # A blockout is flat swatches: far fewer colours than a shipped map.
        check_capture(source, 6);
        shutil.copyfile(source, output / f"scene_{shot}.png");
        source.unlink();
    }
    print(f"SCENE PASS: {len(steps) - 1} steps, 4 brushes, saved as a map and reopened");
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
    scene_session(repo, binary, env, output);
    print(f"Screenshots and logs: {output}");
}

with entry {
    main();
}
