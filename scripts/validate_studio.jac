"""Drive the studio in the real game and check what it did.

Runs `qp` (build it first, or pass --binary) on an active desktop with
scripts/studio/shell_session.cfg: the interface is clicked, typed into and
dragged by scripted input, the document is printed after each step, and
screenshots are taken along the way. A second run without the studio checks
that the saved entities are what the level loads.

    jac run scripts/validate_studio.jac [--binary ./qp] [--only <session>] [--jobs <n>]

`--only shell` is the first session alone. `--jobs <n>` runs the sessions
`n` at a time, each as a run of this script with `--only`: they keep their
settings and scenes in folders of their own, so they do not meet (the three
that pack archives into one folder go one after another).

Output: .jac/screenshots/studio/."""
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import time;
import from concurrent.futures { ThreadPoolExecutor }
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
    shots = ["new", "picked", "edited", "four", "playing", "returned"];
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
        "four", "top-picked", "top-moved", "copied", "ramp", "pillar", "clipped", "turned", "saved", "returned"
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
    # Four views show; a click in the top view picks the door's brush, and a
    # drag there moves it across the floor only.
    assert [line for line in steps["four"] if line.startswith("view ") and line.endswith(" of 4")] , str(steps["four"]);
    assert not brushes(steps["four"]);
    top_picked = brushes(steps["top-picked"]);
    assert len(top_picked) == 1 and brush_box(top_picked[0]) == moved , str(top_picked);
    slid = brush_box(brushes(steps["top-moved"])[0]);
    assert slid[0][0] != moved[0][0] and (slid[0][0] - moved[0][0]) % 8 == 0 , str(slid);
    assert slid[0][1:] == moved[0][1:] and slid[1][1:] == moved[1][1:] , str(slid);
    moved = slid;
    assert "brushes=4" in tally(steps["copied"]) and len(brushes(steps["copied"])) == 1 , str(steps["copied"]);
    # A ramp 48 high and an eight-sided pillar 128 high, both on the floor.
    ramp = brush_box(brushes(steps["ramp"])[0]);
    assert ramp[0][2] == 0 and ramp[1][2] == 48 and ramp[1][1] - ramp[0][1] == 128 , str(ramp);
    pillar = brush_box(brushes(steps["pillar"])[0]);
    assert pillar[0][2] == 0 and pillar[1][2] == 128 and "brushes=6" in tally(steps["pillar"]) , str(pillar);
    # Cut at half height: two brushes selected, one below 64 and one above.
    halves = sorted([brush_box(line) for line in brushes(steps["clipped"])]);
    assert len(halves) == 2 and "brushes=7" in tally(steps["clipped"]) , str(steps["clipped"]);
    assert sorted([half[0][2] for half in halves]) == [0, 64] and sorted([half[1][2] for half in halves]) == [64, 128];
    # R turned both a quarter about their middle: still two, same heights.
    turned = sorted([brush_box(line) for line in brushes(steps["turned"])]);
    assert len(turned) == 2 and sorted([half[1][2] for half in turned]) == [64, 128] , str(turned);
    assert "undo=" in steps["turned"][0] and steps["turned"][0] != steps["clipped"][0];
    assert "dirty=0" in steps["saved"][0];
    # Every geometry edit was followed by a rebuild.
    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert "brushes=7" in built and "entities=3" in steps["returned"][0];

    assert saved_text.startswith("// Format: Valve") and saved_text.count("// brush") == 7;
    assert "\"classname\" \"func_door\"" in saved_text and " brick [" in saved_text;
    reopened = studio_steps(again.stdout)["reopened"];
    assert reopened[0].startswith("passion/studio:yard entities=3") , reopened[0];
    assert "brushes=7" in tally(reopened) and len(brushes(reopened)) == 7 , str(reopened);
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
    print(f"SCENE PASS: {len(steps) - 1} steps, 7 brushes, saved as a map and reopened");
}

"""The face lines of a dump: `face #<brush>/<side> ...`."""
def faces(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("face #")];
}

"""The third session: faces and materials, corners, a rectangle that
selects, hollowing, carving and the map check."""
def tools_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["face", "corner", "checks", "playing"];
    for shot in shots {
        (repo / f"tools_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-tools-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/tools_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "tools.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The tools session failed: {output / 'tools.log'}";
        saved = Path(home) / "scenes/works.map";
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
        (output / "tools_reopen.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Reopening the scene failed: {output / 'tools_reopen.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "boxed", "faced", "painted", "fitted", "slid", "turned", "two-faces", "moded", "hollowed", "second",
        "edged", "cornered", "cleared", "banded", "carved", "tipped", "checked", "saved", "returned"
    ] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'tools.log'}";
    }
    block = brush_box(brushes(steps["boxed"])[0]);
    assert block == [[-64, 96, 0], [64, 224, 96]] , str(block);

    # A click on the block's top in face mode picks that face alone.
    picked = faces(steps["faced"]);
    assert len(picked) == 1 and picked[0].startswith("face #3/4 material=blockout") , str(steps["faced"]);
    assert "mode=face" in steps["faced"][-1] and not brushes(steps["faced"]);
    # A click on a picture in the Materials tab gives the face that material.
    painted = faces(steps["painted"]);
    assert len(painted) == 1 and "material=q1:e1m1/+0basebtn" in painted[0] , str(painted);
    assert "scale=1.0,1.0" in painted[0];
    # Fit lays the 32-texel picture once across the 128-unit face.
    assert "scale=4.0,4.0" in faces(steps["fitted"])[0] , str(steps["fitted"]);
    fitted_shift = faces(steps["fitted"])[0].split("shift=")[1].split()[0].split(",");
    slid_shift = faces(steps["slid"])[0].split("shift=")[1].split()[0].split(",");
    assert float(slid_shift[0]) == float(fitted_shift[0]) + 8.0 and slid_shift[1] == fitted_shift[1];
    assert "turn=90.0" in faces(steps["turned"])[0] , str(steps["turned"]);
    # Ctrl adds the side toward the camera; the first keeps what it was given.
    both = faces(steps["two-faces"]);
    assert len(both) == 2 and both[1].startswith("face #3/4 material=q1:e1m1/+0basebtn") , str(both);
    assert both[0].startswith("face #3/3 material=blockout") , str(both);

    # Back in brush mode the faces' brush is selected, and Hollow makes six walls of it.
    assert "mode=brush" in steps["moded"][-1] and len(brushes(steps["moded"])) == 1;
    assert "brushes=2" in tally(steps["moded"]) and "brushes=7" in tally(steps["hollowed"]) , str(steps["hollowed"]);
    assert len(brushes(steps["hollowed"])) == 6;

    # An edge's handle lifts two corners (six sides still); a corner's splits the top.
    second = brushes(steps["second"]);
    assert len(second) == 1 and brush_box(second[0]) == [[176, 128, 0], [240, 192, 64]] , str(second);
    edged = brushes(steps["edged"]);
    assert brush_box(edged[0]) == [[176, 128, 0], [240, 192, 80]] and "sides=6" in edged[0] , str(edged);
    cornered = brushes(steps["cornered"]);
    assert brush_box(cornered[0]) == [[176, 128, 0], [240, 192, 80]] and "sides=7" in cornered[0] , str(cornered);
    assert "mode=corner" in steps["cornered"][-1] and "wire=10" in steps["cornered"][-1];

    # A rectangle dragged round it in the top view selects it again.
    assert not brushes(steps["cleared"]) and "mode=brush" in steps["cleared"][-1];
    banded = brushes(steps["banded"]);
    assert len(banded) == 1 and banded[0].split()[1] == second[0].split()[1] , str(banded);

    # Sunk eight units and carved, the floor is five pieces round and under it.
    assert "brushes=12" in tally(steps["carved"]) , str(steps["carved"]);
    tipped = brush_box(brushes(steps["tipped"])[0]);
    assert tipped[1][2] - tipped[0][2] == 64 and tipped[1][1] - tipped[0][1] == 80 , str(tipped);

    # The check finds the button that fires nothing; a click on the finding selects it.
    found = [line for line in steps["checked"] if line.startswith("selected ")];
    assert len(found) == 1 and "classname=func_button" in found[0] and "target=nowhere" in found[0] , str(found);
    assert "studio: finding func_button has a target nothing is named: nowhere" in ran.stdout;

    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert "brushes=12" in built;
    assert saved_text.count("// brush") == 12 and "q1:e1m1/+0basebtn [" in saved_text;
    reopened = studio_steps(again.stdout)["reopened"];
    assert "brushes=12" in tally(reopened) and len(brushes(reopened)) == 12 , str(reopened);
    for shot in shots {
        source = repo / f"tools_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"tools_{shot}.png");
        source.unlink();
    }
    print(f"TOOLS PASS: {len(steps) - 1} steps, 12 brushes, saved as a map and reopened");
}

"""The line counting the logic graph's boxes and arrows."""
def logic(lines: list[str]) -> str {
    found = [line for line in lines if line.startswith("logic ")];
    return found[0] if found else "";
}

"""The fourth session: the logic graph, the clipboard, prefabs and groups."""
def logic_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["graph", "library", "playing"];
    for shot in shots {
        (repo / f"logic_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-logic-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/logic_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "logic.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The logic session failed: {output / 'logic.log'}";
        saved = Path(home) / "scenes/logic.map";
        assert saved.exists() , "Saving the scene wrote no map";
        saved_text = saved.read_text();
        prefab = Path(home) / "prefabs/gate.map";
        assert prefab.exists() , "Saving the prefab wrote no map";
        prefab_text = prefab.read_text();
        again = subprocess.run(
            [str(binary), "+edit", "+ed_open", str(saved), "+ed_select", "all", "+ed_dump", "reopened", "+quit"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "logic_reopen.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Reopening the scene failed: {output / 'logic_reopen.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "made", "graphed", "linked", "chained", "picked", "pasted", "added", "placed", "shifted", "crate", "twin",
        "grouped", "saved", "returned"
    ] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'logic.log'}";
    }
    assert "nodes=0 links=0 shown=0" in logic(steps["made"]) , str(steps["made"]);
    # L opens the graph; the two selected entities stand in it, linked to nothing.
    assert "nodes=0 links=0 shown=1" in logic(steps["graphed"]) and len(selected(steps["graphed"])) == 2;
    # A drag from the button's box to the relay's names the relay and aims the button at it.
    linked = selected(steps["linked"]);
    assert "classname=func_button" in linked[0] and "target=t1" in linked[0] , str(linked);
    assert "classname=trigger_relay" in linked[1] and "targetname=t1" in linked[1] , str(linked);
    assert "nodes=2 links=1" in logic(steps["linked"]);
    # A second drag, from the relay to the door, makes a chain of three.
    chained = selected(steps["chained"]);
    assert "target=t2" in chained[1] and "classname=func_door targetname=t2" in chained[2] , str(chained);
    assert "nodes=3 links=2" in logic(steps["chained"]);
    # A click on the door's box, now two columns on, selects it alone.
    picked = selected(steps["picked"]);
    assert len(picked) == 1 and "classname=func_door" in picked[0] and "owns=1" in picked[0] , str(picked);

    # Ctrl+C and Ctrl+V: a second door with a brush of its own, fired by the same relay.
    pasted = selected(steps["pasted"]);
    assert len(pasted) == 1 and pasted[0].startswith("selected #7 classname=func_door targetname=t2 owns=1") , str(pasted);
    assert "brushes=3" in tally(steps["pasted"]) and "nodes=4 links=3 shown=0" in logic(steps["pasted"]);
    # Saved as a prefab from the Library tab, and a copy added by a click on its row.
    assert "\"classname\" \"func_door\"" in prefab_text and prefab_text.count("// brush") == 1;
    added = selected(steps["added"]);
    assert len(added) == 1 and "classname=func_door" in added[0] and "owns=1" in added[0] , str(added);
    assert "brushes=4" in tally(steps["added"]) and "entities=7" in steps["added"][0];
    # A linked prefab is one entity; the level is built again where it stands and where it is moved to.
    placed = selected(steps["placed"]);
    assert len(placed) == 1 and "classname=misc_prefab prefab=gate" in placed[0] , str(placed);
    assert "brushes=4" in tally(steps["placed"]);
    for name in ["placed", "shifted"] {
        built = tally(steps[name]);
        assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    }
    assert tally(steps["placed"]) != tally(steps["shifted"]);
    # Ctrl+G holds the two boxes together as one group.
    grouped = selected(steps["grouped"]);
    assert len(grouped) == 1 and "classname=func_group" in grouped[0] and "owns=2" in grouped[0] , str(grouped);
    assert "brushes=6" in tally(steps["grouped"]);

    assert "\"classname\" \"misc_prefab\"" in saved_text and "\"_group_name\" \"group1\"" in saved_text;
    assert saved_text.count("// brush") == 6;
    reopened = studio_steps(again.stdout)["reopened"];
    assert reopened[0].startswith("passion/studio:logic entities=9") , reopened[0];
    assert "brushes=6" in tally(reopened) and "nodes=5 links=4" in logic(reopened) , str(reopened);
    for shot in shots {
        source = repo / f"logic_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"logic_{shot}.png");
        source.unlink();
    }
    print(f"LOGIC PASS: {len(steps) - 1} steps, a chain of three, a prefab added and linked, a group");
}

"""How many light samples the level was built with (0 when lit flat)."""
def lit(lines: list[str]) -> int {
    found = [line for line in lines if line.startswith("mode=")];
    return int(found[0].split("lit=")[1].split()[0]) if found else -1;
}

"""The fifth session: shapes, light, the class list and the typed inspector."""
def build_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["lit", "inspector", "playing"];
    for shot in shots {
        (repo / f"build_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-build-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/build_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "build.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The build session failed: {output / 'build.log'}";
        saved = Path(home) / "scenes/hall.map";
        assert saved.exists() , "Saving the scene wrote no map";
        saved_text = saved.read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "stairs", "arch", "cone", "lit", "flat", "relit", "door", "flagged", "keyed", "sounded", "angled",
        "turned", "aimed", "followed", "saved", "returned"
    ] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'build.log'}";
    }
    # Stairs and an arch are groups of eight brushes; a cone is one brush of thirteen sides.
    stairs = selected(steps["stairs"]);
    assert len(stairs) == 1 and "_group_name=stairs " in stairs[0] and stairs[0].endswith(" owns=8") , str(stairs);
    # A shape of several brushes keeps the numbers it was built from.
    assert "_shape=stairs 64 128 64 8 16" in stairs[0] , stairs[0];
    arch = selected(steps["arch"]);
    assert len(arch) == 1 and "_group_name=arch " in arch[0] and arch[0].endswith(" owns=8") , str(arch);
    assert "brushes=17" in tally(steps["arch"]);
    cone = brushes(steps["cone"]);
    assert len(cone) == 1 and "sides=13" in cone[0] and brush_box(cone[0])[1][2] == 96 , str(cone);
    # No light, no lightmap; a light lights the level; flat and lit again on request.
    assert lit(steps["cone"]) == 0 and lit(steps["lit"]) > 1000 , str(steps["lit"]);
    assert lit(steps["flat"]) == 0 and lit(steps["relit"]) == lit(steps["lit"]);
    built = tally(steps["lit"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;

    # A click on func_door in the class list makes a door of a new box.
    door = selected(steps["door"]);
    assert len(door) == 1 and door[0].endswith("classname=func_door owns=1") , str(door);
    assert "brushes=19" in tally(steps["door"]);
    # Options ticked one at a time, a sound chosen from a list, an angle typed and turned.
    assert "spawnflags=1 " in selected(steps["flagged"])[0] , str(steps["flagged"]);
    assert "spawnflags=9 " in selected(steps["keyed"])[0] , str(steps["keyed"]);
    assert "sounds=1 " in selected(steps["sounded"])[0] , str(steps["sounded"]);
    assert "angle=90 " in selected(steps["angled"])[0] , str(steps["angled"]);
    assert "angle=135 " in selected(steps["turned"])[0] , str(steps["turned"]);
    # The arrow beside a button's target selects what it fires.
    aimed = selected(steps["aimed"]);
    assert len(aimed) == 1 and "classname=func_button" in aimed[0] and "target=gate" in aimed[0] , str(aimed);
    followed = selected(steps["followed"]);
    assert len(followed) == 1 and "classname=func_door" in followed[0] and "targetname=gate" in followed[0];

    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert saved_text.count("// brush") == 19 and "\"spawnflags\" \"9\"" in saved_text;
    assert "\"_group_name\" \"stairs\"" in saved_text and "\"classname\" \"light\"" in saved_text;
    for shot in shots {
        source = repo / f"build_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"build_{shot}.png");
        source.unlink();
    }
    print(f"BUILD PASS: {len(steps) - 1} steps, shapes, a lit level, a door made and set from the inspector");
}

"""The sixth session: copies as images, and the leak finder."""
def images_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["row", "leak"];
    for shot in shots {
        (repo / f"images_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-images-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/images_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "images.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The images session failed: {output / 'images.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["post", "imaged", "shifted", "real", "leaking", "ringed", "open", "roofed", "sealed"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'images.log'}";
    }
    # A post grouped and asked for three copies: one brush in the document, built with its images.
    imaged = selected(steps["imaged"]);
    assert len(imaged) == 1 and "_copies=3 _offset=48 0 0 owns=1" in imaged[0] , str(imaged);
    assert "brushes=2" in tally(steps["imaged"]);
    for name in ["imaged", "shifted"] {
        built = tally(steps[name]);
        assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    }
    assert tally(steps["imaged"]) != tally(steps["shifted"]);
    # Made real, the group owns the post and its three copies and asks for no more.
    real = selected(steps["real"]);
    assert len(real) == 1 and real[0].endswith("owns=4") and "_copies" not in real[0] , str(real);
    assert "brushes=5" in tally(steps["real"]);
    # An open yard leaks; so does a ring of walls without a roof; with one it is sealed.
    assert "leak=0" in logic(steps["real"]) and "leak=0" not in logic(steps["leaking"]) , str(steps["leaking"]);
    assert "leak=0" in logic(steps["ringed"]) and "leak=0" not in logic(steps["open"]) , str(steps["open"]);
    assert ran.stdout.count("studio: leak ends") == 2 and ran.stdout.count("studio: leak sealed after") == 1;
    assert "leak=0" in logic(steps["sealed"]) and "brushes=6" in tally(steps["roofed"]);
    for shot in shots {
        source = repo / f"images_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"images_{shot}.png");
        source.unlink();
    }
    print(f"IMAGES PASS: {len(steps) - 1} steps, a row of images made real, a leak found and sealed");
}

"""The seventh session: a shipped Quake II level and a Quake III arena
turned into scenes of their own brushes, and a generated expedition when
one loads."""
def convert_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "convert_level.png").unlink(missing_ok=True);
    counts: dict[str, int] = {};
    skipped = "";
    for (game, level, least, marker) in [
        ("q2", "base1", 1000, " q2:e1u1/"), ("q3", "q3dm1", 500, " q3:textures/"), ("passion", "v2-42", 200, "")
    ] {
        with tempfile.TemporaryDirectory(prefix="qp-convert-") as home {
            env["QP_CONFIG_DIR"] = home;
            env["QP_OVERRIDES"] = home + "/overrides";
            env["QP_SCENES"] = home + "/scenes";
            env["QP_GAME"] = game;
            env["QP_MAP"] = level;
            ran = subprocess.run(
                [str(binary), "+ed_exec", "scripts/studio/convert_session.cfg"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                timeout=600
            );
            (output / f"convert_{game}.log").write_text(ran.stdout + ran.stderr);
            steps = studio_steps(ran.stdout);
            if game == "passion" and "shipped" not in steps {
                # The expedition itself did not load, in or out of the studio:
                # nothing here to convert, and not this session's to fix.
                reason = [line for line in (ran.stdout + ran.stderr).splitlines() if "Uncaught exception" in line];
                skipped = reason[0] if reason else "the level did not load";
                continue;
            }
            assert ran.returncode == 0 , f"Converting {game}/{level} failed: {output / f'convert_{game}.log'}";
            assert "converted" in steps and "saved" in steps , f"{output / f'convert_{game}.log'}";
            assert steps["shipped"][0].startswith(game + "/" + level) and not tally(steps["shipped"]);
            assert steps["converted"][0].startswith("passion/studio:" + level) , steps["converted"][0];
            made = int(tally(steps["converted"]).split("brushes=")[1].split()[0]);
            assert made >= least , f"{game}/{level} gave only {made} brushes";
            entities = steps["shipped"][0].split("entities=")[1].split()[0];
            assert ("entities=" + entities) in steps["converted"][0] , steps["converted"][0];
            saved = Path(home) / ("scenes/" + level + ".map");
            assert saved.exists() , "Saving the converted level wrote no map";
            saved_text = saved.read_text();
            assert saved_text.count("// brush") == made;
            assert not marker or marker in saved_text , "The brushes lost their materials";
            # The saved map opens as the same scene.
            again = subprocess.run(
                [str(binary), "+edit", "+ed_open", str(saved), "+ed_dump", "reopened", "+quit"],
                cwd=repo,
                env=env,
                capture_output=True,
                text=True,
                timeout=600
            );
            (output / f"convert_{game}_reopen.log").write_text(again.stdout + again.stderr);
            assert again.returncode == 0 , f"Reopening {level} failed";
            reopened = studio_steps(again.stdout)["reopened"];
            assert ("brushes=" + str(made)) in tally(reopened) , str(reopened[:4]);
            counts[game] = made;
            source = repo / "convert_level.png";
            if source.exists() {
                shutil.copyfile(source, output / f"convert_{game}.png");
                source.unlink();
            }
        }
    }
    env["QP_GAME"] = "q1";
    env["QP_MAP"] = "e1m1";
    # A map file as a Quake III editor writes it opens with its brushDef
    # brush and its patchDef2 patch.
    with tempfile.TemporaryDirectory(prefix="qp-arena-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_SCENES"] = home + "/scenes";
        opened = subprocess.run(
            [
                str(binary), "+edit", "+ed_open", "scripts/studio/fixtures/arena.map", "+ed_dump", "opened",
                "+quit"
            ],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "arena_open.log").write_text(opened.stdout + opened.stderr);
        assert opened.returncode == 0 , f"Opening the arena map failed: {output / 'arena_open.log'}";
        arena = studio_steps(opened.stdout)["opened"];
        assert arena[0].startswith("passion/studio:arena entities=3") , arena[0];
        assert "brushes=33" in tally(arena) and patches(arena) == ["patch #2 3x3 top=128 prisms=32"] , str(arena);
    }
    print(
        f"CONVERT PASS: base1 as {counts['q2']} brushes and q3dm1 as {counts['q3']}, saved as maps and reopened; "
            + "a brushDef and patchDef2 map opened"
    );
    if "passion" in counts {
        print(f"CONVERT PASS: expedition v2-42 as {counts['passion']} brushes");
    } else {
        print(f"CONVERT SKIPPED for expedition v2-42: {skipped}");
    }
}

"""The eighth session: the asset explorer and archive packing."""
def assets_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    import zipfile;
    import struct;
    shots = ["texture", "text", "model", "found"];
    for shot in shots {
        (repo / f"assets_{shot}.png").unlink(missing_ok=True);
    }
    pack = repo / ".jac/studio-pack";
    shutil.rmtree(pack, ignore_errors=True);
    with tempfile.TemporaryDirectory(prefix="qp-assets-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_EXTRACT"] = str(pack / "extract");
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/assets_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_EXTRACT");
        (output / "assets.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The assets session failed: {output / 'assets.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["boxed", "texture", "used", "text", "sound", "model", "turned", "playing", "arena", "packed"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'assets.log'}";
    }
    shown = [line for line in steps["texture"] if line.startswith("asset ")];
    assert len(shown) == 1 and shown[0].startswith("asset q2:textures/e1u1/metal1_1.wal kind=image") , str(shown);
    assert "note=64x64" in shown[0] and shown[0].endswith("material=q2:e1u1/metal1_1");
    # Use as material gives the texture to the selected brush.
    assert "material=blockout" in brushes(steps["boxed"])[0];
    assert "material=q2:e1u1/metal1_1" in brushes(steps["used"])[0] , str(steps["used"]);
    # Extract writes the file as the archive has it: a WAL's name, then its size.
    wal = pack / "extract/q2/textures/e1u1/metal1_1.wal";
    assert wal.exists() , "Extract wrote no file";
    data = wal.read_bytes();
    assert data[:17] == b"e1u1/metal1_1\x00\x00\x00\x00" and struct.unpack("<II", data[32:40]) == (64, 64);
    assert f"studio: extracted {len(data)} bytes" in ran.stdout;
    text = [line for line in steps["text"] if line.startswith("asset ")];
    assert len(text) == 1 and "kind=text" in text[0] and int(text[0].split("lines=")[1].split()[0]) > 20 , str(text);
    sound = [line for line in steps["sound"] if line.startswith("asset ")];
    assert len(sound) == 1 and "kind=sound" in sound[0] and "note=11025Hz,1channel" in sound[0] , str(sound);
    assert "studio: played sound/misc/menu1.wav" in ran.stdout , "The sound's Play button played nothing";
    # A search by name lists files from the archives (and nothing else when there is none).
    found = [line for line in ran.stdout.splitlines() if line.startswith("studio: found ")];
    assert len(found) >= 1 and int(found[0].split()[2]) >= 1 , str(found);
    # Quake's player model: one surface, 143 frames, shown at its first.
    figure = [line for line in steps["model"] if line.startswith("model ")];
    assert len(figure) == 1 and figure[0].startswith("model q1:progs/player.mdl surfaces=1 frames=143 triangles=408 frame=0") , str(figure);
    start_yaw = int(figure[0].split("yaw=")[1].split()[0]);
    # A drag to the left turns it about a third of a radian a hundred pixels' worth; > steps a frame.
    turned = [line for line in steps["turned"] if line.startswith("model ")][0];
    assert "frame=1 " in turned and 25 <= int(turned.split("yaw=")[1].split()[0]) - start_yaw <= 45 , turned;
    assert "edges=612" in turned;
    playing = [line for line in steps["playing"] if line.startswith("model ")][0];
    assert "playing=1" in playing and int(playing.split("frame=")[1].split()[0]) > 1 , playing;
    arena = [line for line in steps["arena"] if line.startswith("model ")][0];
    assert arena.startswith("model q3:models/players/sarge/upper.md3 surfaces=2 frames=153") , arena;
    # The scene packed with the texture it uses is a zip any tool reads.
    with zipfile.ZipFile(pack / "crate.pk3") as archive {
        assert archive.testzip() is None;
        assert archive.namelist() == ["maps/crate.map", "textures/e1u1/metal1_1.wal"] , str(archive.namelist());
        assert archive.read("textures/e1u1/metal1_1.wal") == data;
        assert b"q2:e1u1/metal1_1 [" in archive.read("maps/crate.map");
    }
    # The folder packed as a PAK: its header, and the one file's directory entry.
    packed = (pack / "extract.pak").read_bytes();
    assert packed[:4] == b"PACK";
    (where, size) = struct.unpack("<ii", packed[4:12]);
    assert size == 64 and packed[where:where + 33] == b"q2/textures/e1u1/metal1_1.wal\x00\x00\x00\x00";
    assert struct.unpack("<ii", packed[where + 56:where + 64]) == (12, len(data)) and packed[12:12 + len(data)] == data;
    assert ran.stdout.count("studio: packed ") == 2;
    for shot in shots {
        source = repo / f"assets_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"assets_{shot}.png");
        source.unlink();
    }
    shutil.rmtree(pack, ignore_errors=True);
    print(
        f"ASSETS PASS: {len(steps) - 1} steps, a texture shown, used and extracted, a model turned and played, "
            + "a scene and a folder packed"
    );
}

"""A value from the dump's last line: `grid=16` gives 16."""
def setting(lines: list[str], key: str) -> int {
    found = [line for line in lines if line.startswith("mode=")];
    return int(found[0].split(key + "=")[1].split()[0]) if found else -1;
}

"""The ninth session: the grid, remembered views, hiding, dropping, the
history list and the autosave."""
def handy_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["history", "palette", "light"];
    for shot in shots {
        (repo / f"handy_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-handy-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/handy_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "handy.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The handy session failed: {output / 'handy.log'}";
        autosave = Path(home) / "scenes/autosave/handy.map";
        assert autosave.exists() , "The autosave wrote no map";
        autosave_text = autosave.read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in [
        "boxed", "coarse", "fine", "lifted", "dropped", "returned", "hid", "shown", "alone", "before", "undone",
        "typed", "found", "picked"
    ] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'handy.log'}";
    }
    # The grid is 8 to begin with, 32 by command, 64 by ] and 16 by [ twice.
    assert setting(steps["boxed"], "grid") == 8 and setting(steps["coarse"], "grid") == 64;
    assert setting(steps["fine"], "grid") == 16;
    # Lifted forty units, End lets the brush down onto the floor again.
    start = brush_box(brushes(steps["boxed"])[0]);
    assert brush_box(brushes(steps["lifted"])[0])[0][2] == start[0][2] + 40;
    assert brush_box(brushes(steps["dropped"])[0]) == start , str(steps["dropped"]);
    # The remembered view is where the camera goes back to.
    assert "camera 0 -420 260" in steps["returned"][1] , steps["returned"][1];
    # Remembering it is an edit of the document, like any other.
    assert "undo=4" in steps["returned"][0] and "undo=3" in steps["dropped"][0];
    # Hidden, the brush is out of the selection and out of the edited level; then back.
    assert setting(steps["hid"], "hidden") == 1 and not brushes(steps["hid"]);
    for name in ["hid", "shown", "alone"] {
        built = tally(steps[name]);
        assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    }
    assert setting(steps["shown"], "hidden") == 0 and setting(steps["alone"], "hidden") == 2;
    assert len(brushes(steps["alone"])) == 1;
    # The second line of the history list undoes two edits.
    before = int(steps["before"][0].split("undo=")[1].split()[0]);
    after = int(steps["undone"][0].split("undo=")[1].split()[0]);
    assert after == before - 2 , f"{before} -> {after}";
    assert "redo=2" in steps["undone"][0];
    picked = selected(steps["picked"]);
    assert len(picked) == 1 and "classname=info_player_start" in picked[0] , str(picked);
    # The palette runs what is typed with its words, and finds a command by a few letters.
    assert setting(steps["typed"], "grid") == 4 , str(steps["typed"][-1]);
    assert "leak=0" in logic(steps["typed"]) and "leak=0" not in logic(steps["found"]) , str(steps["found"]);
    for shot in shots {
        source = repo / f"handy_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"handy_{shot}.png");
        source.unlink();
    }
    print(
        f"HANDY PASS: {len(steps) - 1} steps, grid, drop, a remembered view, hiding, history, the palette and autosave"
    );
}

"""The terrain line of a dump as numbers: its tallest corner and how many
corners are raised."""
def terrain(lines: list[str]) -> list[int] {
    found = [line for line in lines if line.startswith("terrain #")];
    if not found {
        return [-1, -1];
    }
    return [int(found[0].split("tallest=")[1].split()[0]), int(found[0].split("raised=")[1].split()[0])];
}

"""The tenth session: terrain made, sculpted and read from an image."""
def terrain_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["hills", "playing"];
    for shot in shots {
        (repo / f"terrain_{shot}.png").unlink(missing_ok=True);
    }
    pack = repo / ".jac/studio-pack";
    shutil.rmtree(pack, ignore_errors=True);
    with tempfile.TemporaryDirectory(prefix="qp-terrain-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/terrain_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "terrain.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The terrain session failed: {output / 'terrain.log'}";
        saved_text = (Path(home) / "scenes/hills.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in ["made", "raised", "stroked", "lowered", "flat", "read", "returned"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'terrain.log'}";
    }
    # Eight by eight cells, two prisms each, on the scene's floor.
    assert terrain(steps["made"]) == [0, 0] and "brushes=129" in tally(steps["made"]);
    made = [line for line in steps["made"] if line.startswith("terrain #")];
    assert " 8x8 cell=64 " in made[0] , str(made);
    # A stroke by command raises a hill; dragging the brush raises more, a dab at a time.
    raised = terrain(steps["raised"]);
    assert raised[0] > 50 and raised[1] > 5 , str(raised);
    stroked = terrain(steps["stroked"]);
    edits = int(steps["stroked"][0].split("undo=")[1].split()[0]);
    assert stroked[1] > raised[1] and edits >= 5 , f"{stroked} after {edits} edits";
    assert "mode=sculpt" in steps["stroked"][-1];
    # Shift lowers: one more edit.
    assert int(steps["lowered"][0].split("undo=")[1].split()[0]) == edits + 1;
    # Flattened, then the heights written out before the drag come back.
    assert terrain(steps["flat"])[0] <= 2;
    assert terrain(steps["read"]) == [96, raised[1]] , str(terrain(steps["read"]));
    image = (pack / "hills.pgm").read_text();
    assert image.startswith("P2\n9 9\n255\n") and len(image.splitlines()) == 12;
    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert "\"_terrain\" \"8 8 64 16\"" in saved_text and saved_text.count("// brush") == 129;
    for shot in shots {
        source = repo / f"terrain_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"terrain_{shot}.png");
        source.unlink();
    }
    shutil.rmtree(pack, ignore_errors=True);
    print(f"TERRAIN PASS: {len(steps) - 1} steps, a terrain sculpted by command and by dragging, heights out and in");
}

"""The patch lines of a dump: `patch #n WxH top=Z prisms=N`."""
def patches(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("patch #")];
}

"""The eleventh session: curved patches made, bent and moved."""
def patch_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["arch", "playing"];
    for shot in shots {
        (repo / f"patch_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-patch-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/patch_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "patch.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The patch session failed: {output / 'patch.log'}";
        saved_text = (Path(home) / "scenes/curves.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in ["made", "bent", "dragged", "moved", "tube", "cone", "returned"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'patch.log'}";
    }
    # An arch is five by three control points and sixty-four prisms, its crown at the top of its box.
    made = patches(steps["made"]);
    assert len(made) == 1 and made[0] == "patch #3 5x3 top=96 prisms=64" , str(made);
    assert "_patch=5 3 4 8" in selected(steps["made"])[0];
    # A control point lifted by command, then one dragged thirty-two units sideways in the front view.
    assert patches(steps["bent"])[0] == "patch #3 5x3 top=128 prisms=64" , str(steps["bent"]);
    before = selected(steps["bent"])[0].split("_points=")[1].split(" owns=")[0].split();
    after = selected(steps["dragged"])[0].split("_points=")[1].split(" owns=")[0].split();
    changed = [i for i in range(len(before)) if before[i] != after[i]];
    assert changed == [9] and int(after[9]) == int(before[9]) + 32 , f"{changed}: {before[9:12]} -> {after[9:12]}";
    assert int(steps["dragged"][0].split("undo=")[1].split()[0]) == int(steps["bent"][0].split("undo=")[1].split()[0]) + 1;
    # Moved as a whole, every control point moved with it.
    moved = selected(steps["moved"])[0].split("_points=")[1].split(" owns=")[0].split();
    assert [int(moved[i]) - int(after[i]) for i in range(0, len(after), 3)] == [64] * 15;
    assert [int(moved[i]) - int(after[i]) for i in range(1, len(after), 3)] == [0] * 15;
    # A cylinder is a tube of nine by three; a cone pinches to a point and so has fewer prisms.
    tube = [line for line in patches(steps["tube"]) if " 9x3 " in line];
    assert len(tube) == 1 and tube[0].endswith("prisms=128") , str(tube);
    cones = [line for line in patches(steps["cone"]) if " 9x3 " in line];
    assert len(cones) == 2 and len([line for line in cones if not line.endswith("prisms=128")]) == 1 , str(cones);
    built = tally(steps["returned"]);
    assert built.split("geometry=")[1].split()[0] == built.split("built=")[1].split()[0] , built;
    assert saved_text.count("\"_patch\"") == 3 and "\"_patch\" \"5 3 4 8\"" in saved_text;
    for shot in shots {
        source = repo / f"patch_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"patch_{shot}.png");
        source.unlink();
    }
    print(f"PATCH PASS: {len(steps) - 1} steps, an arch bent by command and by a drag, a cylinder and a cone");
}

"""The twelfth session: snapping, a material replaced, brushes lined up
and glued, face picks spread, and the counts."""
def tidy_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "tidy_faces.png").unlink(missing_ok=True);
    pack = repo / ".jac/studio-pack";
    shutil.rmtree(pack, ignore_errors=True);
    with tempfile.TemporaryDirectory(prefix="qp-tidy-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/tidy_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "tidy.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The tidy session failed: {output / 'tidy.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["askew", "snapped", "replaced", "aligned", "glued", "others", "every", "stepped", "frozen", "thawed"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'tidy.log'}";
    }
    askew = brush_box(brushes(steps["askew"])[0]);
    snapped = brush_box(brushes(steps["snapped"])[0]);
    # Moved (3, -2, 1) off the grid, the box snaps back to where it was made.
    assert [snapped[0][i] - askew[0][i] for i in range(3)] == [-3, 2, -1] , f"{askew} -> {snapped}";
    assert snapped[0][0] % 8 == 0 and snapped[0][1] % 8 == 0 and snapped[0][2] == 0;
    assert "material=stone" in brushes(steps["replaced"])[0] , str(steps["replaced"]);
    # Lined up by their undersides: the small box comes down to the floor.
    aligned = [brush_box(line) for line in brushes(steps["aligned"])];
    assert len(aligned) == 2 and aligned[0][0][2] == 0 and aligned[1][0][2] == 0 , str(aligned);
    # Glued, the small box's low x is the big one's high x.
    glued = brush_box(brushes(steps["glued"])[0]);
    assert glued[0][0] == snapped[1][0] and glued[1][0] == snapped[1][0] + 32 , f"{glued} against {snapped}";
    assert len(faces(steps["others"])) == 5 and len(faces(steps["every"])) == 6;
    assert "studio: stat 2 entities, 3 brushes, 18 sides" in ran.stdout;
    assert "studio: stat 6 sides of stone" in ran.stdout and "studio: stat 6 sides of brick" in ran.stdout;
    # Tab selects the first entity; frozen, a click in the level changes nothing; thawed, it does.
    stepped = selected(steps["stepped"]);
    assert len(stepped) == 1 and "classname=info_player_start" in stepped[0] , str(stepped);
    assert selected(steps["frozen"]) == stepped and setting(steps["frozen"], "frozen") == 1 , str(steps["frozen"]);
    assert selected(steps["thawed"]) != stepped and setting(steps["thawed"], "frozen") == 0 , str(steps["thawed"]);
    # The check names the material no archive holds, and the names in use are written a line each.
    assert "studio: finding No archive holds the material q2:e1u1/no_such_texture (brush #4)" in ran.stdout;
    names = (pack / "materials.txt").read_text().split();
    assert names == sorted(names) and "q2:e1u1/no_such_texture" in names and "stone" in names , str(names);
    shutil.rmtree(pack, ignore_errors=True);
    source = repo / "tidy_faces.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "tidy_faces.png");
    source.unlink();
    print(
        f"TIDY PASS: {len(steps) - 1} steps, snapped, replaced, lined up, glued, faces spread, counted, stepped, "
            + "frozen, checked for materials"
    );
}

"""The thirteenth session: a box drawn in the top view, cut along a drawn
line, and the settings kept between runs."""
def draw_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["box", "cut", "arrows"];
    for shot in shots {
        (repo / f"draw_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-draw-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/draw_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "draw.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The draw session failed: {output / 'draw.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        # Opened again, the studio is as it was left: the grid, four views, the axis views as edges.
        again = subprocess.run(
            [str(binary), "+edit", "+wait", "+wait", "+ed_dump", "again", "+quit"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "draw_again.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Opening the studio again failed: {output / 'draw_again.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["four", "drawn", "cut", "trimmed", "start", "pulled"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'draw.log'}";
    }
    # A rectangle dragged in the top view: a box on the grid, sixty-four high, standing on the floor.
    drawn = brushes(steps["drawn"]);
    assert len(drawn) == 1 and "mode=draw" in steps["drawn"][-1] , str(steps["drawn"]);
    box = brush_box(drawn[0]);
    assert box[0][2] == 0 and box[1][2] == 64 and box[1][0] - box[0][0] == 192 and box[1][1] - box[0][1] == 192 , str(box);
    assert [value % 16 for value in box[0] + box[1]] == [0] * 6;
    # A line drawn down through it leaves two brushes that meet at the line, each of six sides.
    halves = [brush_box(line) for line in brushes(steps["cut"])];
    assert len(halves) == 2 and halves[0][1][0] == halves[1][0][0] , str(halves);
    assert halves[0][0][0] == box[0][0] and halves[1][1][0] == box[1][0];
    assert all(["sides=6" in line for line in brushes(steps["cut"])]) , str(steps["cut"]);
    # With Shift, a line across both keeps only what is behind it.
    trimmed = [brush_box(line) for line in brushes(steps["trimmed"])];
    assert len(trimmed) == 2 and trimmed[0][1][1] == trimmed[1][1][1] and trimmed[0][1][1] < box[1][1] , str(trimmed);
    assert trimmed[0][0][1] == box[0][1];
    # The player start's red arrow, dragged forty pixels in the top view, takes it 128 units along x.
    start = selected(steps["start"]);
    pulled = selected(steps["pulled"]);
    assert len(start) == 1 and "origin=0 0 24" in start[0] and "origin=128 0 24" in pulled[0] , f"{start} -> {pulled}";
    assert "ed_grid 16" in kept and "ed_layout 4" in kept and "ed_display wire axis" in kept , kept;
    back = studio_steps(again.stdout)["again"];
    assert setting(back, "grid") == 16 and "wire=10" in back[-1] , back[-1];
    assert [line for line in back if line.startswith("view ")][0].endswith(" of 4") , str(back);
    for shot in shots {
        source = repo / f"draw_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"draw_{shot}.png");
        source.unlink();
    }
    print(
        f"DRAW PASS: {len(steps) - 1} steps, a box drawn and cut along drawn lines, an entity moved by its arrow, "
            + "the settings kept"
    );
}

"""A word of the line that says what the last bake did."""
def bake_word(lines: list[str], key: str) -> int {
    found = [line for line in lines if line.startswith("bake ")];
    return int(found[0].split(key + "=")[1].split()[0]) if found else -1;
}

"""The thirty-first session: a walled hall cut into cells that know what
they see, and played with less drawn from one side of its wall."""
def bake_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "bake_cells.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-bake-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/bake_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "bake.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The bake session failed: {output / 'bake.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["opened", "baked", "inside", "whole", "unbaked"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'bake.log'}";
    }
    assert made(steps["opened"]) == 7 and bake_word(steps["opened"], "cells") == -1 , str(steps["opened"]);
    # Cut into cells: more than one, some out of sight of others, and no budget spent.
    cells = bake_word(steps["baked"], "cells");
    assert cells >= 8 and bake_word(steps["baked"], "hidden") > 0 and bake_word(steps["baked"], "capped") == 0 , str(
        steps["baked"]
    );
    assert bake_word(steps["baked"], "pairs") == cells * (cells - 1) // 2;
    # Played from one side of the wall, fewer faces are drawn than when the level is one leaf.
    inside = int(played_word(steps["inside"], "drawn"));
    whole = int(played_word(steps["unbaked"], "drawn"));
    assert 0 < inside and inside < whole , f"{inside} of {whole}";
    assert bake_word(steps["whole"], "cells") == -1;
    source = repo / "bake_cells.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "bake_cells.png");
    source.unlink();
    print(
        f"BAKE PASS: {len(steps) - 1} steps, a hall cut into {cells} cells with some out of sight of others, "
            + f"{inside} faces drawn from one side of its wall against {whole} built as one"
    );
}

"""A number from a step's line that begins with `prefix`: the word after `key=`."""
def line_word(lines: list[str], prefix: str, key: str) -> str {
    found = [line for line in lines if line.startswith(prefix)];
    return found[0].split(key + "=")[1].split()[0] if found else "";
}

"""The thirty-second session: a bake's cells shown from where one looks, a
bake kept and given back, recipes, and another program run over the map."""
def steps_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["cells", "recipes"];
    for shot in shots {
        (repo / f"steps_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-steps-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/steps_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "steps.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The steps session failed: {output / 'steps.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        written = (Path(home) / "scenes/hall.build.map").read_text();
        heard = (Path(home) / "scenes/hall.build.map.log").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "opened", "west", "east", "start", "moved", "undone", "inside", "stopped", "recipes", "quick", "fine", "forgot",
        "ran", "first", "second", "third"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'steps.log'}";
    }
    # Cells: looked from the west room and from the east, each sees itself
    # and its own side, not everything; the player start stands in the west.
    cells = bake_word(steps["west"], "cells");
    west = int(line_word(steps["west"], "cells ", "from"));
    east = int(line_word(steps["east"], "cells ", "from"));
    seen = int(line_word(steps["west"], "cells ", "sees"));
    assert cells >= 8 and int(line_word(steps["west"], "cells ", "of")) == cells , str(steps["west"]);
    assert west >= 0 and east >= 0 and west != east and 1 < seen and seen < cells , str(steps["west"]);
    assert int(line_word(steps["start"], "cells ", "from")) == west , str(steps["start"]);
    assert not [line for line in steps["opened"] if line.startswith("cells ")];
    # A bake is worked out once for a thing: after the undo, and after a
    # game played and stopped, the one kept is given back.
    assert line_word(steps["west"], "build ", "from") == "new" , str(steps["west"]);
    assert line_word(steps["moved"], "build ", "from") == "new" , str(steps["moved"]);
    assert line_word(steps["undone"], "build ", "from") == "copy" , str(steps["undone"]);
    assert line_word(steps["stopped"], "build ", "from") == "copy" , str(steps["stopped"]);
    for name in ["undone", "stopped"] {
        assert bake_word(steps[name], "cells") == cells;
        assert bake_word(steps[name], "hidden") == bake_word(steps["west"], "hidden") , str(steps[name]);
    }
    # Played with the bake given back, less than all of it is drawn from the west.
    drawn = int(played_word(steps["inside"], "drawn"));
    assert 0 < drawn and drawn < 42 , str(steps["inside"]);
    # Recipes: both listed, each run, one forgotten, the other kept in the settings.
    listed = [line for line in steps["recipes"] if line.startswith("recipe ")];
    assert listed == ["recipe fine = ed_build full; ed_bake 128", "recipe quick = ed_build quick; ed_bake off"] , str(listed);
    assert bake_word(steps["quick"], "cells") == -1 and bake_word(steps["fine"], "cells") == cells , str(steps["fine"]);
    assert [line for line in steps["quick"] if line.startswith("making quick steps=2")] or [
        line for line in steps["recipes"] if line.startswith("making quick steps=2")
    ];
    left = [line for line in steps["forgot"] if line.startswith("recipe ")];
    assert left == ["recipe fine = ed_build full; ed_bake 128"] , str(left);
    assert 'ed_recipe fine "ed_build full; ed_bake 128"' in kept and "ed_recipe quick" not in kept , kept;
    # Another program: it was given the scene as a map, stopped with its own
    # code, and what it said of an entity, a brush and a line is gone to.
    assert "// brush 6" in written and "fakebsp" in heard and "brushes: 7" in heard , heard;
    told = [line for line in steps["ran"] if line.startswith("ran ")];
    assert told and "code=3" in told[0] and "lines=6" in told[0] and "places=3" in told[0] and "plain=1" in told[0] , str(
        steps["ran"]
    );
    said = [line for line in steps["ran"] if line.startswith("said ")];
    assert len(said) == 3 and said[0].startswith("said entity=0 brush=3 Entity 0, Brush 3") , str(said);
    assert said[1].startswith("said entity=1 brush=-1") and said[2].startswith("said entity=0 brush=5") , str(said);
    assert len(brushes(steps["first"])) == 1 and brushes(steps["first"])[0].startswith("brush #4 low=256,-128,0 ") , str(steps["first"]);
    assert len(selected(steps["second"])) == 1 and "info_player_start" in selected(steps["second"])[0] , str(
        steps["second"]
    );
    assert len(brushes(steps["third"])) == 1 and brushes(steps["third"])[0].startswith("brush #6 ") , str(steps["third"]);
    for shot in shots {
        source = repo / f"steps_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"steps_{shot}.png");
        source.unlink();
    }
    print(
        f"STEPS PASS: {len(steps) - 1} steps, {seen} of {cells} cells seen from the west room, a bake given back after "
            + "an undo and a game, recipes kept and run, and a compiler's three complaints gone to"
    );
}

"""A word of a step's `modeldoc` line: what follows `key=`."""
def model_word(lines: list[str], key: str) -> str {
    found = [line for line in lines if line.startswith("modeldoc ")];
    return found[0].split(" " + key + "=")[1].split()[0] if found and (" " + key + "=") in found[0] else "";
}

"""The thirty-ninth session: a model made, reshaped, given a frame and a
second part, checked, saved as MD3 and OBJ, and opened again."""
def model_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["new", "marks"];
    for shot in shots {
        (repo / f"model_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-model-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/model_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "model.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The model session failed: {output / 'model.log'}";
        md3 = (Path(home) / "models/tower.md3").read_bytes();
        wavefront = (Path(home) / "models/tower.obj").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "made", "picked", "extruded", "second", "first", "cut", "inside_out", "righted", "two", "clicked", "unclicked",
        "closed", "reopened"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'model.log'}";
    }
    # An eight-sided cylinder 64 across and 96 tall: closed, and holding what one would.
    made_now = steps["made"];
    assert model_word(made_now, "parts") == "1" and model_word(made_now, "points") == "18" and model_word(made_now, "triangles") == "32" , str(
        made_now
    );
    assert model_word(made_now, "open") == "0" and abs(int(model_word(made_now, "volume")) - 278045) <= 2 and model_word(made_now, "high") == "32,32,96";
    # Its top's eight triangles and their nine points picked, and pushed out 32 on walls.
    assert model_word(steps["picked"], "picked") == "9/8" , str(steps["picked"]);
    pushed = steps["extruded"];
    assert model_word(pushed, "triangles") == "48" and model_word(pushed, "points") == "26" and model_word(pushed, "open") == "0";
    assert model_word(pushed, "high") == "32,32,128" and abs(int(model_word(pushed, "volume")) - 370727) <= 2 , str(pushed);
    # A second frame, sixteen higher; the first where it was.
    assert model_word(steps["second"], "frames") == "2" and model_word(steps["second"], "frame") == "1:raised";
    assert model_word(steps["second"], "low") == "-32,-32,16" and model_word(steps["second"], "high") == "32,32,144" , str(steps["second"]);
    assert model_word(steps["first"], "frame").startswith("0:") and model_word(steps["first"], "low") == "-32,-32,0";
    # Cut in four it holds the same; turned round, less than nothing; undone, the same again.
    assert model_word(steps["cut"], "triangles") == "192" and model_word(steps["cut"], "open") == "0";
    assert abs(int(model_word(steps["cut"], "volume")) - 370727) <= 2 and abs(int(model_word(steps["inside_out"], "volume")) + 370727) <= 2;
    assert abs(int(model_word(steps["righted"], "volume")) - 370727) <= 2 and model_word(steps["righted"], "triangles") == "192";
    # A ball as a second part, in hand; nothing wrong; both files written.
    assert model_word(steps["two"], "parts") == "2" and model_word(steps["two"], "part") == "1" and model_word(steps["two"], "triangles") == "48";
    listed = [line for line in steps["righted"] if line.startswith("part ")];
    assert len(listed) == 2 and listed[1].endswith("in hand") , str(steps["righted"]);
    assert "faults 0" in steps["two"] , str(steps["two"]);
    # The panel's buttons: Cut in 4 on the ball, then Undo.
    assert model_word(steps["clicked"], "triangles") == "192" and model_word(steps["clicked"], "part") == "1" , str(steps["clicked"]);
    assert model_word(steps["unclicked"], "triangles") == "48" , str(steps["unclicked"]);
    assert md3[:4] == b"IDP3" and int.from_bytes(md3[76:80], "little") == 2 and int.from_bytes(md3[84:88], "little") == 2;
    assert wavefront.startswith("# Written by the QuakePassion studio.") and wavefront.count("\nf ") == 48;
    # Closed, and opened again from the MD3: both parts and both frames, the second as high as it was.
    assert not [line for line in steps["closed"] if line.startswith("modeldoc ")];
    again = steps["reopened"];
    assert model_word(again, "parts") == "2" and model_word(again, "frames") == "2" and model_word(again, "frame") == "1:raised";
    assert model_word(again, "triangles") == "192" and model_word(again, "high") == "32,32,144" and model_word(again, "open") == "0" , str(
        again
    );
    for shot in shots {
        source = repo / f"model_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"model_{shot}.png");
        source.unlink();
    }
    print(
        f"MODEL PASS: {len(steps) - 1} steps, a cylinder made, its top pushed out, a second frame, triangles cut and turned "
            + "round and that undone, a second part, and the model saved as MD3 and OBJ and opened again"
    );
}

"""The numbers of a `patch lies` or `patch places` line."""
def lay_numbers(line: str) -> list[float] {
    words = line.split()[4:] if line.startswith("studio: patch places") else line.split()[3:];
    return [] if words in [["none"], ["nowhere"]] else [float(word) for word in words];
}

"""The fiftieth session: a patch told where its control points lie on its
material."""
def lay_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "lay_bent.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-lay-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/lay_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "lay.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The lay session failed: {output / 'lay.log'}";
        saved_text = (Path(home) / "scenes/lay.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "boxed", "made", "fitted", "twice", "slid", "row", "column", "point", "bent", "tagged", "projected", "grown",
        "shrunk", "cleared", "refused", "back"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'lay.log'}";
    }
    # Every time the patch says where its points lie, and where its built faces have the material.
    told = [lay_numbers(line) for line in ran.stdout.splitlines() if line.startswith("studio: patch places ")];
    lies = [lay_numbers(line) for line in ran.stdout.splitlines() if line.startswith("studio: patch lies ")];
    assert len(told) == 13 and len(lies) == 13 , f"{len(told)} {len(lies)}";
    # New, it has been told nothing: its faces take the material plainly, a texel a unit of the world.
    assert told[0] == [] and lies[0] == [-64.0, -96.0, 64.0, -224.0] , f"{told[0]} {lies[0]}";
    assert "_st=" not in selected(steps["made"])[0];
    # Spread once: the material's own size from its first corner to its last.
    wide = lies[1][2];
    tall = lies[1][3];
    assert lies[1][:2] == [0.0, 0.0] and wide >= 8.0 and tall >= 8.0 , str(lies[1]);
    assert told[1] == [0.0, 0.0, wide / 2, 0.0, wide, 0.0, 0.0, tall / 2, wide / 2, tall / 2, wide, tall / 2, 0.0, tall, wide / 2, tall, wide, tall];
    assert "_st=" + " ".join([str(int(each)) for each in told[1]]) + " owns=32" in selected(steps["fitted"])[0];
    # Twice across; all of it slid; its last row; its first column; one corner.
    assert lies[2] == [0.0, 0.0, wide * 2, tall] , str(lies[2]);
    assert lies[3] == [16.0, 8.0, wide * 2 + 16, tall + 8] , str(lies[3]);
    assert lies[4] == [16.0, 8.0, wide * 2 + 16, tall + 40] and told[4][:6] == told[3][:6] and told[4][13] == told[3][13] + 32;
    assert lies[5] == [12.0, 8.0, wide * 2 + 16, tall + 40] and [told[5][i] - told[4][i] for i in [0, 6, 12, 2, 8]] == [-4.0, -4.0, -4.0, 0.0, 0.0];
    assert lies[6] == [-16.0, -8.0, wide * 2 + 16, tall + 40] and told[6][2:] == told[5][2:] , str(lies[6]);
    undone = [int(steps[name][0].split("undo=")[1].split()[0]) for name in ["made", "fitted", "twice", "slid", "row", "column", "point", "bent"]];
    assert undone == [undone[0] + count for count in range(8)] , str(undone);
    # Bent, the patch keeps its places: its corners lie where they did, and the file has them.
    assert patches(steps["bent"])[0] == "patch #4 3x3 top=96 prisms=32" and told[7] == told[6] and lies[7] == lies[6];
    assert "\"_st\" \"" + " ".join([str(int(each)) for each in told[6]]) + "\"" in saved_text;
    # From the tagged top of the box: each point where the box's material would have it.
    tagged = faces(steps["tagged"]);
    assert len(tagged) == 1 and face_word(tagged[0], "shift") == "8.0,4.0" and face_word(tagged[0], "scale") == "1.0,1.0";
    assert told[8][:6] == [-56.0, -92.0, 8.0, -92.0, 72.0, -92.0] and lies[8] == [-56.0, -92.0, 72.0, -220.0] , str(told[8]);
    # A wider grid has no places; undone, they are back.
    assert patches(steps["grown"])[0].startswith("patch #4 5x3 ") and "_st=" not in selected(steps["grown"])[0] and told[9] == [];
    assert told[10] == told[8] and lies[10] == lies[8] and "_st=" in selected(steps["shrunk"])[0];
    # Forgotten: plain again, and there is nothing then to slide or forget.
    assert told[11] == [] and lies[11] == lies[0] and "_st=" not in selected(steps["cleared"])[0];
    assert steps["refused"][0] == steps["cleared"][0] and selected(steps["refused"])[0] == selected(steps["cleared"])[0];
    assert told[12] == told[8] and lies[12] == lies[8] and "_st=" in selected(steps["back"])[0];
    source = repo / "lay_bent.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "lay_bent.png");
    source.unlink();
    print(
        f"LAY PASS: {len(steps) - 1} steps, a patch's material spread, slid by rows, columns and a point, kept through "
            + "a bend, taken from a tagged face, and forgotten"
    );
}

"""The fifty-first session: one box handle that moves, turns, sizes and
shears, and the same by number."""
def lean_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["shearing", "pair", "3d"];
    for shot in shots {
        (repo / f"lean_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-lean-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/lean_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "lean.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The lean session failed: {output / 'lean.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = [
        "boxed", "sheared", "squared", "turned", "sized", "taller", "leant", "moved", "tipped", "pair", "both",
        "numeric", "linear", "refused", "level"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'lean.log'}";
    }
    boxes: dict[str, list[list[list[int]]]] = {};
    for name in names {
        boxes[name] = [brush_box(line) for line in brushes(steps[name])];
        assert len([line for line in brushes(steps[name]) if "sides=6" in line]) == len(boxes[name]) , str(steps[name]);
    }
    undone = [int(steps[name][0].split("undo=")[1].split()[0]) for name in names];
    # A box twice as long as it is deep, with the one handle round it.
    assert boxes["boxed"] == [[[-288, 112, 0], [-96, 208, 64]]] and "handles=box" in handles(steps["boxed"]) , str(steps["boxed"]);
    # Its right edge taken forty-eight units along itself: the far end of the box is that much further
    # up the plan and the near end where it was. A shear, for sheared back by a quarter it is a box
    # of the size it had (a size would have left it half as deep again).
    assert boxes["sheared"] == [[[-288, 112, 0], [-96, 256, 64]]] and undone[1] == undone[0] + 1 , str(boxes["sheared"]);
    assert boxes["squared"] == [[[-288, 136, 0], [-96, 232, 64]]] , str(boxes["squared"]);
    # A corner taken a quarter of the way round: the box stands the other way about its middle.
    assert boxes["turned"] == [[[-240, 64, 0], [-144, 256, 64]]] , str(boxes["turned"]);
    # With Shift the same corner sizes it, the far corner staying put.
    assert boxes["sized"] == [[[-288, 112, 0], [0, 208, 64]]] , str(boxes["sized"]);
    # The top edge pulled outward sizes that way alone; taken along itself it shears the other way.
    assert boxes["taller"] == [[[-288, 112, 0], [-96, 256, 64]]] , str(boxes["taller"]);
    assert boxes["leant"] == [[[-288, 112, 0], [-48, 208, 64]]] , str(boxes["leant"]);
    # The middle moves it; and each drag was one step, undone before the next.
    assert boxes["moved"] == [[[-224, 112, 0], [-32, 208, 64]]] , str(boxes["moved"]);
    assert undone[3:9] == [undone[1]] * 6 , str(undone);
    # In the front view the handle lies along x and z: its top taken along leans the box over.
    assert boxes["tipped"] == [[[-288, 112, 0], [-64, 208, 64]]] , str(boxes["tipped"]);
    # Two brushes under one handle, sheared as one: the far end of the far one goes the whole way,
    # the near end of the near one nowhere, and what lies between in proportion.
    pair = sorted(boxes["pair"]);
    both = sorted(boxes["both"]);
    assert len(pair) == 2 and pair[0] == [[-288, 112, 0], [-96, 208, 64]] , str(pair);
    wide = pair[1][1][0] - pair[0][0][0];
    assert both[1][1][1] == pair[1][1][1] + 48 and both[0][0][1] == pair[0][0][1] , str(both);
    assert abs(both[0][1][1] - (208 + 48 * 192 / wide)) <= 1 and abs(both[1][0][1] - (112 + 48 * (pair[1][0][0] + 288) / wide)) <= 1;
    assert [box[0][0] for box in both] == [box[0][0] for box in pair] and [box[1][0] for box in both] == [box[1][0] for box in pair];
    # By number: half a unit along x for each unit of height, about the pair's middle.
    numeric = sorted(boxes["numeric"]);
    for (index, box) in enumerate(numeric) {
        assert box[1][0] - box[0][0] == pair[index][1][0] - pair[index][0][0] + 32 , str(numeric);
        assert box[0][1:] == pair[index][0][1:] and box[1][1:] == pair[index][1][1:] , str(numeric);
    }
    # A quarter turn said as what the axes become, about the world's middle.
    turned = sorted(boxes["linear"]);
    assert [[-208, -288, 0], [-112, -96, 64]] in turned and len(turned) == 2 , str(turned);
    # A change that would flatten the selection, and a shear of an axis along itself, change nothing.
    assert sorted(boxes["refused"]) == pair and sorted(boxes["level"]) == pair , str(boxes["refused"]);
    for shot in shots {
        source = repo / f"lean_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"lean_{shot}.png");
        source.unlink();
    }
    print(
        f"LEAN PASS: {len(steps) - 1} steps, one box handle shearing, turning, sizing and moving a brush in two views, "
            + "two brushes sheared as one, and shears and turns by number"
    );
}

"""A `lay` line's handles: where they stand and the two arms, as number lists."""
def lay_handles(lines: list[str]) -> list[list[float]] {
    found = [line for line in lines if line.startswith("lay #")];
    if not found {
        return [];
    }
    return [[float(part) for part in found[0].split(" " + key + "=")[1].split()[0].split(",")] for key in ["at", "s", "t"]];
}

"""The fifty-second session: handles on a face for its material."""
def arms_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["stretching", "aslant"];
    for shot in shots {
        (repo / f"arms_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-arms-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/arms_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "arms.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The arms session failed: {output / 'arms.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["picked", "shown", "stretched", "aslant", "turned", "slid", "finer", "numeric", "refused", "hidden"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'arms.log'}";
    }
    undone = [int(steps[name][0].split("undo=")[1].split()[0]) for name in names];
    # The top of the box picked: no handles until they are asked for; then a dot at its middle
    # and an arm a repeat of the material long each way it runs.
    assert len(faces(steps["picked"])) == 1 and lay_handles(steps["picked"]) == [];
    shown = lay_handles(steps["shown"]);
    assert shown == [[-192.0, 160.0, 64.0], [64.0, 0.0, 0.0], [0.0, -64.0, 0.0]] , str(shown);
    plain = faces(steps["shown"])[0];
    assert face_word(plain, "shift") == "0.0,0.0" and face_word(plain, "scale") == "1.0,1.0";
    # The first arm taken out to twice its length: twice as coarse that way, the other as it was,
    # and the material where the handles stand has not moved (so its shift takes that up).
    stretched = lay_handles(steps["stretched"]);
    assert stretched[1:] == [[128.0, 0.0, 0.0], [0.0, -64.0, 0.0]] and undone[2] == undone[1] + 1 , str(stretched);
    assert face_word(faces(steps["stretched"])[0], "scale") == "2.0,1.0" and face_word(faces(steps["stretched"])[0], "shift") == "-96.0,0.0";
    # Swung an eighth of the way round by itself: that way runs aslant, the other as it did.
    aslant = lay_handles(steps["aslant"]);
    assert aslant[1:] == [[48.0, 48.0, 0.0], [0.0, -64.0, 0.0]] , str(aslant);
    # With Shift both go round together and neither grows.
    turned = lay_handles(steps["turned"]);
    assert turned[1:] == [[0.0, 64.0, 0.0], [64.0, 0.0, 0.0]] and face_word(faces(steps["turned"])[0], "scale") == "1.0,1.0" , str(turned);
    # The dot slides the material thirty-two units along with it.
    slid = faces(steps["slid"])[0];
    assert face_word(slid, "shift") == "-32.0,0.0" and face_word(slid, "scale") == "1.0,1.0" and lay_handles(steps["slid"]) == shown , slid;
    # The second arm pulled in to half its length.
    finer = lay_handles(steps["finer"]);
    assert finer[1:] == [[64.0, 0.0, 0.0], [0.0, -32.0, 0.0]] and face_word(faces(steps["finer"])[0], "scale") == "1.0,0.5" , str(finer);
    assert undone[3:7] == [undone[2]] * 4 , str(undone);
    # In numbers: slid, and twice as fine both ways. A lie whose ways run together is refused.
    numeric = faces(steps["numeric"])[0];
    assert face_word(numeric, "shift") == "8.0,4.0" and face_word(numeric, "scale") == "0.5,0.5" , numeric;
    assert lay_handles(steps["numeric"])[1:] == [[32.0, 0.0, 0.0], [0.0, -32.0, 0.0]];
    assert faces(steps["refused"])[0] == numeric and undone[8] == undone[7];
    assert lay_handles(steps["hidden"]) == [] and faces(steps["hidden"])[0] == numeric;
    for shot in shots {
        source = repo / f"arms_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"arms_{shot}.png");
        source.unlink();
    }
    print(
        f"ARMS PASS: {len(steps) - 1} steps, a face's material stretched, swung one way alone, turned and slid by "
            + "handles on the face, and laid by number"
    );
}

"""A step's `bone` lines by the bone's name: its words by key."""
def bone_rows(lines: list[str]) -> dict[str, dict[str, str]] {
    found: dict[str, dict[str, str]] = {};
    for line in lines {
        if line.startswith("bone ") {
            words = line.split();
            found[words[1]] = {word.split("=")[0]: word.split("=")[1] for word in words[2:] if "=" in word};
        }
    }
    return found;
}

"""A bone's end from its line, as numbers."""
def bone_end(row: dict[str, str], key: str) -> list[float] {
    return [float(part) for part in row[key].split(",")];
}

"""The fifty-third session: a model's bones."""
def bones_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["shared", "dragged"];
    for shot in shots {
        (repo / f"bones_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-bones-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/bones_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "bones.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The bones session failed: {output / 'bones.log'}";
        kept = (Path(home) / "models/arm.md3.rig").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "made", "rigged", "shared", "freed", "turned", "undone", "dragged", "spread", "rest", "closed", "reopened",
        "dropped"
    ];
    for name in names {
        assert name in steps and (steps[name] or name == "closed") , f"The session never reached '{name}': {output / 'bones.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    # A column with no bones says nothing of bones; then two, the second hanging from the first
    # and carrying on from its end, with the eighteen points shared out by which is nearer.
    assert bone_rows(steps["made"]) == {} and "bones took 18" in said;
    rigged = bone_rows(steps["rigged"]);
    assert list(rigged.keys()) == ["upper", "fore"] and rigged["fore"]["parent"] == "upper" and rigged["upper"]["parent"] == "-";
    assert rigged["upper"]["tail"] == "0,0,48" and rigged["fore"]["head"] == "0,0,48" and rigged["fore"]["tail"] == "0,0,96";
    assert rigged["upper"]["carries"] == "9" and rigged["fore"]["carries"] == "9" and rigged["upper"]["tint"] != rigged["fore"]["tint"];
    # Two points of the top ring half given to the lower bone: the upper keeps the other half.
    assert "weight 8 upper:0.5 fore:0.5" in said and "weight 9 upper:0.5 fore:0.5" in said;
    shared = bone_rows(steps["shared"]);
    assert shared["upper"]["carries"] == "11" and shared["fore"]["carries"] == "9";
    assert [line for line in steps["shared"] if line.startswith("bones 2 hand=upper colours=1")] , str(steps["shared"]);
    # Let go by the lower bone, they are half carried; taken whole by the upper again.
    assert "bones freed 2" in said and "weight 8 fore:0.5" in said and bone_rows(steps["freed"])["upper"]["carries"] == "9";
    # The forearm thirty degrees about x: its end swings over, its joint and the other bone stay,
    # and the top of the column goes with it.
    turned = bone_rows(steps["turned"]);
    assert turned["fore"]["head"] == "0,0,48" and turned["fore"]["tail"] == "0,-24,89.57" and turned["upper"] == bone_rows(steps["freed"])["upper"];
    high = [line for line in steps["turned"] if line.startswith("modeldoc ")][0];
    assert "high=32,32,96" not in high and "undo=1" in high and "low=-32,-52,0" in high , high;
    undone = [line for line in steps["undone"] if line.startswith("modeldoc ")][0];
    assert "low=-32,-32,0 high=32,32,96" in undone and "undo=0" in undone and bone_rows(steps["undone"])["fore"]["tail"] == "0,0,96";
    # Its end dragged a quarter of the way round its joint as seen: as long as it was, its joint
    # where it was, lying level now; and the click that ended the drag picked nothing.
    assert "bone dragged fore 90" in said;
    dragged = bone_rows(steps["dragged"]);
    end = bone_end(dragged["fore"], "tail");
    reach = (end[0] ** 2 + end[1] ** 2 + (end[2] - 48.0) ** 2) ** 0.5;
    assert dragged["fore"]["head"] == "0,0,48" and abs(reach - 48.0) < 0.1 and abs(end[2] - 48.0) < 6.0 , str(end);
    was_dragged = [line for line in steps["dragged"] if line.startswith("modeldoc ")][0];
    assert "picked=0/0" in was_dragged and "undo=1" in was_dragged , was_dragged;
    # Three frames, the last bent sixty degrees: the one between is set half way, and the first is at rest.
    spread = bone_rows(steps["spread"]);
    assert "frames=3 frame=1:mid" in [line for line in steps["spread"] if line.startswith("modeldoc ")][0];
    assert spread["fore"]["tail"] == "0,-20.78,84" and bone_rows(steps["rest"])["fore"]["tail"] == "0,0,96";
    # Kept beside the model's file, and back with it when it is opened again.
    assert "bone upper - " in kept and "bone fore upper " in kept and "at 2 0 0 48 0 -41.5692 72" in kept and kept.count("grip 0 ") == 2;
    assert not [line for line in steps["closed"] if line.startswith("bone")];
    reopened = bone_rows(steps["reopened"]);
    assert list(reopened.keys()) == ["upper", "fore"] and reopened["fore"]["parent"] == "upper" and reopened["fore"]["tail"] == "0,-41.57,72";
    assert reopened["fore"]["carries"] == "9" and reopened["upper"]["carries"] == "9" and reopened["fore"]["tint"] == rigged["fore"]["tint"];
    # The lower bone taken away: the other hangs from nothing, where it was.
    dropped = bone_rows(steps["dropped"]);
    assert list(dropped.keys()) == ["fore"] and dropped["fore"]["parent"] == "-" and dropped["fore"]["tail"] == reopened["fore"]["tail"];
    for shot in shots {
        source = repo / f"bones_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"bones_{shot}.png");
        source.unlink();
    }
    print(
        f"BONES PASS: {len(steps) - 1} steps, two bones jointed, points shared by weight, a bone turned by command and "
            + "by a drag, frames spread between two poses, and the bones kept with the model"
    );
}

"""The fifty-fourth session: a body put together, and weapons as held in view."""
def figure_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["stood", "shotgun", "machinegun"];
    for shot in shots {
        (repo / f"figure_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-figure-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/figure_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "figure.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The figure session failed: {output / 'figure.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["stood", "running", "other", "shotgun", "firing", "second", "third", "refused", "edited"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'figure.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    shown: dict[str, str] = {};
    for name in names {
        shown[name] = [line for line in steps[name] if line.startswith("model ")][0];
    }
    # Quake III's bodies are found by their legs; Sarge is one, Visor another.
    bodies = [line for line in said if line.startswith("bodies ")][0].split()[1:];
    assert "sarge" in bodies and "visor" in bodies and len(bodies) >= 20 , str(bodies);
    made = [line for line in said if line.startswith("body ")];
    # At rest with a machinegun: legs, torso, head and gun, the frames of the legs' idling
    # (the torso stands on one frame, held through them).
    assert made[0].startswith("body sarge legs=idle:") and "torso=stand:" in made[0] and made[0].endswith("weapon=machinegun surfaces=6") , made[0];
    idle = int(made[0].split("legs=idle:")[1].split()[0].split("+")[1]);
    assert made[0].split("torso=stand:")[1].split()[0].endswith("+1") and idle > 1;
    assert shown["stood"].startswith("model q3:body/sarge/idle+stand+machinegun surfaces=6 frames=" + str(idle) + " ") , shown["stood"];
    triangles = int(shown["stood"].split("triangles=")[1].split()[0]);
    # Running while it attacks, empty handed: as many frames as the longer of the two, and fewer triangles.
    run = int(made[1].split("legs=run:")[1].split()[0].split("+")[1]);
    attack = int(made[1].split("torso=attack:")[1].split()[0].split("+")[1]);
    assert made[1].endswith("weapon=none surfaces=5") and f"frames={max(run, attack)} " in shown["running"] and "frame=3 " in shown["running"];
    assert 0 < int(shown["running"].split("triangles=")[1].split()[0]) < triangles , shown["running"];
    # Another body with another weapon.
    assert made[2].startswith("body visor ") and "weapon=rocketl" in made[2] and shown["other"].startswith("model q3:body/visor/idle+stand+rocketl ");
    # Quake's shotgun as held: its rest and the six frames of a shot, seen from the eye (no turn).
    held = [line for line in said if line.startswith("viewweapon ")];
    assert held[0] == "viewweapon q1 slot=2 model=progs/v_shot.mdl frames=7 hand=0 barrel=0 surfaces=1" , held[0];
    assert shown["shotgun"].startswith("model q1:held/progs/v_shot.mdl surfaces=1 frames=7 ") and " yaw=0 " in shown["shotgun"];
    assert "frame=4 " in shown["firing"] , shown["firing"];
    # Quake II's shotgun; Quake III's machinegun on its hand, with its barrel, seen from outside.
    assert held[1].startswith("viewweapon q2 slot=2 model=models/weapons/v_shotg/tris.md2 ") and "hand=0" in held[1] and " yaw=0 " in shown["second"];
    assert held[2] == "viewweapon q3 slot=2 model=models/weapons2/machinegun/machinegun.md3 frames=7 hand=1 barrel=1 surfaces=2" , held[2];
    assert " yaw=0 " not in shown["third"] and "surfaces=2 frames=7 " in shown["third"];
    # A body, a sequence, a game and a slot that are not there change nothing.
    assert shown["refused"] == shown["third"] and len(made) == 4 and len(held) == 3 and "viewweapons q1 1 2 3 4 5 6 7 8" in said;
    # Taken into the model editor it is a model of five parts with the body's frames.
    edited = [line for line in steps["edited"] if line.startswith("modeldoc ")][0];
    assert " parts=5 " in edited and f" frames={idle} " in edited and made[3].endswith("weapon=none surfaces=5") , edited;
    for shot in shots {
        source = repo / f"figure_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"figure_{shot}.png");
        source.unlink();
    }
    print(
        f"FIGURE PASS: {len(steps) - 1} steps, a body of {len(bodies)} put together at rest and running, and three games' "
            + "weapons as held in view"
    );
}

"""The fifty-fifth session: the Passion districts' materials as data."""
def district_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-district-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/district_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "district.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The district session failed: {output / 'district.log'}";
        left = (Path(home) / "overrides/passion/districts.txt").exists();
    }
    steps = studio_steps(ran.stdout);
    for name in ["listed", "changed", "refused", "checked", "one_back", "all_back"] {
        assert name in steps , f"The session never reached '{name}': {output / 'district.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: district")];
    # Each listing: six districts, each with its name and its five slots.
    rows = [line for line in said if line.startswith("district ") and " floor=" in line];
    assert len(rows) == 30 , str(len(rows));
    lists = [rows[index:index + 6] for index in range(0, 30, 6)];
    plain = lists[0];
    assert plain[0] == "district 0 Stone_Keep floor=q1:e1m2/stone1_3 wall=q1:e1m2/wbrick1_5 ceiling=q1:e1m2/wizmet1_2 "
        + "trim=q1:e1m2/wizmet1_7 accent=q1:e1m2/wizwood1_5" , plain[0];
    assert plain[5].startswith("district 5 Arena_Works floor=q3:textures/base_floor/diamond2c ");
    # A floor from another game, a wall from the material in hand, and a name: only that district changes.
    changed = lists[1];
    assert changed[0] == "district 0 The_Keep_Below floor=q2:e1u1/floor3_1 wall=q1:e1m1/tech04_1 ceiling=q1:e1m2/wizmet1_2 "
        + "trim=q1:e1m2/wizmet1_7 accent=q1:e1m2/wizwood1_5" , changed[0];
    assert changed[1:] == plain[1:];
    sets = [line for line in said if line.startswith("district ") and " floor=" not in line and not line.startswith("district loads") and not line.startswith("district slot")];
    assert sets[:3] == ["district 0 floor q2:e1u1/floor3_1", "district 0 wall q1:e1m1/tech04_1", "district 0 name The_Keep_Below"] , str(sets);
    # A material the archives do not hold, a word that names none, a slot and a district that are not: nothing changes.
    assert lists[2] == changed and len(sets) == 4 , str(sets);
    # Checked: every slot's material is there, and what a level is made with (through the game's own
    # loader, which reads the kept file) has the first district's floor and wall as they were set.
    loads = [line for line in said if line.startswith("district loads ")];
    assert "districts missing=0" in said and len(loads) == 6 , str(loads);
    assert loads[0] == "district loads 0 q2:e1u1/floor3_1 q1:tech04_1 q1:wizmet1_2 q1:wizmet1_7 q1:wizwood1_5" , loads[0];
    assert loads[2] == "district loads 2 q2:e1u1/floor3_1 q2:e1u1/metal3_2 q2:e1u1/ceil1_1 q2:e1u1/box1_3 q2:e1u1/box3_1" , loads[2];
    assert not [line for line in said if line.startswith("district slot ")];
    # One district put back, then (after another is changed) all of them; and the file is gone.
    assert lists[3] == plain and sets[3] == "district 3 accent q3:textures/base_wall/concrete" and lists[4] == plain and not left;
    print(
        "DISTRICT PASS: 6 steps, a district's slots given other materials and a name, what is not there refused, "
            + "the game's own loader reading the table, and the table put back"
    );
}

"""A step's floating windows by number: their words by key."""
def float_rows(lines: list[str]) -> dict[int, dict[str, str]] {
    found: dict[int, dict[str, str]] = {};
    for line in lines {
        if line.startswith("window ") {
            words = line.split();
            found[int(words[1])] = {word.split("=")[0]: word.split("=")[1] for word in words[2:] if "=" in word};
        }
    }
    return found;
}

"""The fifty-sixth session: floating 3D windows."""
def float_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["one", "two"];
    for shot in shots {
        (repo / f"float_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-float-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/float_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "float.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The float session failed: {output / 'float.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["none", "opened", "moved", "sized", "dollied", "picked", "escaped", "two", "closed", "kept", "gone"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'float.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    rows: dict[str, dict[int, dict[str, str]]] = {};
    cameras: dict[str, str] = {};
    for name in names {
        rows[name] = float_rows(steps[name]);
        cameras[name] = [line for line in steps[name] if line.startswith("camera ")][0];
    }
    # None to begin with; then one, numbered after the first view, where it was put, looking from where it was told.
    assert rows["none"] == {} and said.count("windows 0") == 2;
    opened = rows["opened"];
    assert list(opened.keys()) == [2] and opened[2]["at"] == "600,300" and opened[2]["size"] == "340x240" , str(opened);
    assert opened[2]["eye"] == "300,-300,200" and opened[2]["yaw"] == "135" and opened[2]["pitch"] == "-20" and opened[2]["outlines"] == "0";
    # Dragged by its bar two hundred left and a hundred and fifty up; then its corner out sixty by forty.
    assert rows["moved"][2]["at"] == "400,150" and rows["moved"][2]["size"] == "340x240" , str(rows["moved"]);
    assert rows["sized"][2]["at"] == "400,150" and rows["sized"][2]["size"] == "400x280" , str(rows["sized"]);
    # The wheel over it moved its own camera: the first view's stayed where it was.
    assert rows["dollied"][2]["eye"] != rows["sized"][2]["eye"] and rows["dollied"][2]["yaw"] == "135";
    assert cameras["dollied"] == cameras["sized"] and cameras["sized"] == cameras["opened"] , cameras["dollied"];
    # Looking straight at the box from its own camera, a click in the window picked the box.
    assert not brushes(steps["escaped"]) and len(brushes(steps["picked"])) == 1 , str(steps["picked"]);
    assert brushes(steps["picked"])[0].startswith("brush #3 ") and rows["picked"][2]["eye"] == "-150,160,32";
    # Escape let go of the selection and left the window.
    assert list(rows["escaped"].keys()) == [2];
    # A second, in outlines, over the first; its cross closes it and leaves the other.
    two = rows["two"];
    assert list(two.keys()) == [2, 3] and two[3]["at"] == "560,260" and two[3]["size"] == "300x220" and two[3]["outlines"] == "1";
    assert list(rows["closed"].keys()) == [2] and rows["closed"][2] == two[2];
    # Sent far off, it stays within the views; told to draw in outlines, it does; a window that is not there changes nothing.
    kept = rows["kept"][2];
    corner = [int(part) for part in kept["at"].split(",")];
    reach = [int(part) for part in kept["size"].split("x")];
    assert reach == [400, 280] and corner[0] > 400 and corner[1] > 150 and corner[0] + reach[0] <= 1000 and corner[1] + reach[1] <= 720 , str(kept);
    assert kept["outlines"] == "1" and list(rows["kept"].keys()) == [2] and rows["gone"] == {};
    for shot in shots {
        source = repo / f"float_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"float_{shot}.png");
        source.unlink();
    }
    print(
        f"FLOAT PASS: {len(steps) - 1} steps, a floating 3D window moved, sized, flown and clicked through with its own "
            + "camera, a second in outlines closed by its cross, and both kept within the views"
    );
}

"""A `nav` line's numbers by key."""
def nav_words(line: str) -> dict[str, int] {
    return {word.split("=")[0]: int(word.split("=")[1]) for word in line.split()[1:] if "=" in word};
}

"""The fifty-seventh session: navigation for bots, baked."""
def nav_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "nav_baked.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-nav-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/nav_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "nav.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The nav session failed: {output / 'nav.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["built", "baked", "checked", "coarse", "cleared"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'nav.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: nav")];
    # Nothing is baked for a shipped level, nor for a scene until it is asked for.
    assert said[0] == "nav none" and said[1] == "nav none" , str(said[:3]);
    # A floor 512 square in cells of 32 is sixteen by sixteen: the two boxes' tops stand in for the
    # floor under them, so the places to stand are as many as that.
    baked = nav_words([line for line in steps["baked"] if line.startswith("nav cell=")][0]);
    assert baked["cell"] == 32 and baked["floors"] == 256 and baked["areas"] == 256 and baked["shown"] == 1 , str(baked);
    # Each box is two cells by two, with eight ways across its edge: the low one is jumped onto and
    # dropped from, the tall one only dropped from; everything else is walked.
    assert baked["jump"] == 8 and baked["drop"] == 16 and baked["walk"] + 24 == baked["ways"] and baked["walk"] > 800 , str(baked);
    routes = [int(line.split("time=")[1]) for line in said if line.startswith("nav route ")];
    assert len(routes) == 5 , str(routes);
    # Across the floor there is a way; up the tall box none, down from it one; onto the low box one,
    # longer than the walk; and none to a place off the level.
    assert routes[0] > 0 and routes[1] == -1 and routes[2] > 0 and routes[3] > routes[0] and routes[4] == -1 , str(routes);
    # Of two things added, the one on the tall box cannot be reached.
    lost = [line for line in said if line.startswith("nav lost ")];
    assert "nav checked lost=1" in said and len(lost) == 1 and "info_notnull" in lost[0] and "cannot be reached" in lost[0] , str(lost);
    # A coarser bake: cells of 64, fewer places and ways.
    coarse = nav_words([line for line in steps["coarse"] if line.startswith("nav cell=")][0]);
    assert coarse["cell"] == 64 and 40 < coarse["floors"] < 70 and coarse["ways"] < baked["ways"] and coarse["jump"] == 4 , str(coarse);
    # Forgotten: nothing is baked, and there is nothing to ask the way of.
    assert said[-1] == "nav none" and not [line for line in steps["cleared"] if line.startswith("nav ")];
    source = repo / "nav_baked.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "nav_baked.png");
    source.unlink();
    print(
        f"NAV PASS: {len(steps) - 1} steps, {baked['floors']} places to stand and {baked['ways']} ways baked, routes found "
            + "by the engine's router, one thing out of reach named"
    );
}

"""The fifty-eighth session: what clicks pick, editing kept to the selection, and a map forced on to the grid."""
def restrict_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-restrict-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/restrict_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "restrict.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The restrict session failed: {output / 'restrict.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "passed", "floor", "entity", "kept", "released", "shown", "mended", "stood"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'restrict.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    hidden: dict[str, int] = {};
    for name in names {
        hidden[name] = int([line for line in steps[name] if line.startswith("mode=")][0].split("hidden=")[1].split()[0]);
    }
    # Nothing selected to begin with. Told to pick entities only, a click on a box passes it.
    assert not brushes(steps["made"]) and not selected(steps["made"]);
    assert not brushes(steps["passed"]) and not selected(steps["passed"]) and "picks=entities put_away=0" in steps["passed"];
    # Told to pick brushes only, a click where the entity stands takes the floor under it.
    assert len(brushes(steps["floor"])) == 1 and brushes(steps["floor"])[0].startswith("brush #1 ") and not selected(steps["floor"]);
    # Told to pick everything again, the same click takes the entity; and the dump no longer speaks of it.
    assert len(selected(steps["entity"])) == 1 and "classname=info_notnull" in selected(steps["entity"])[0] and not brushes(steps["entity"]);
    assert not [line for line in steps["entity"] if line.startswith("picks=")];
    # One box hidden by hand; editing kept to the other puts three more things away (the floor and
    # the two entities), and letting go brings those three back and leaves the one hidden before.
    assert "picks=all put_away=3" in steps["kept"] and hidden["kept"] == 4 and brushes(steps["kept"])[0].startswith("brush #3 ");
    assert hidden["released"] == 1 and not [line for line in steps["released"] if line.startswith("picks=")] and hidden["shown"] == 0;
    # Knocked off the grid, the box and the entity (and the start, which stands off a grid of sixteen)
    # are forced back on; asked again there is nothing to do.
    mends = [line for line in said if line.startswith("snapped all ")];
    assert mends == ["snapped all grid=16 off=3 moved=3 left=0", "snapped all grid=16 off=0 moved=0 left=0"] , str(mends);
    assert brush_box(brushes(steps["mended"])[0]) == [[-288, 112, 0], [-96, 208, 64]] , str(steps["mended"]);
    assert "origin=0 0 48" in selected(steps["stood"])[0] , str(selected(steps["stood"]));
    print(
        f"RESTRICT PASS: {len(steps) - 1} steps, clicks picking entities only, brushes only and both, editing kept to "
            + "a selection and let go, and a map forced on to the grid"
    );
}

"""The fifty-ninth session: a map imported, materials found and lately used, a folder extracted."""
def finds_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "finds_shelf.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-finds-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_EXTRACT"] = home + "/out";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/finds_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_EXTRACT");
        (output / "finds.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The finds session failed: {output / 'finds.log'}";
        written = sorted([str(path.relative_to(Path(home) / "out")) for path in (Path(home) / "out").rglob("*") if path.is_file()]);
        sizes = sum([path.stat().st_size for path in (Path(home) / "out").rglob("*") if path.is_file()]);
    }
    steps = studio_steps(ran.stdout);
    for name in ["empty", "imported", "missing", "found", "recent", "extracted"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'finds.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    # A new scene has a floor and a start. The hall's map brings its seven brushes, as a group,
    # and its start and two lights: one step. A file that is not there changes nothing.
    assert "entities=2 " in steps["empty"][0] and tally(steps["empty"]).startswith("brushes=1 ");
    assert "entities=6 " in steps["imported"][0] and "undo=1" in steps["imported"][0] and tally(steps["imported"]).startswith("brushes=8 ");
    assert steps["missing"][0] == steps["imported"][0] and tally(steps["missing"]) == tally(steps["imported"]);
    # Materials named for crates, in more than one game; none for a word nothing holds.
    finds = [line for line in said if line.startswith("matfind ")];
    count = int(finds[0].split("found=")[1].split()[0]);
    assert finds[0].startswith("matfind crate found=") and count >= 8 and "q1:e1m1/crate0_side" in finds[0] , finds[0];
    assert finds[1].startswith("matfind no_such_material_anywhere found=0");
    # Three taken in hand, one of them twice: the latest first, each once.
    assert "recent materials blockout q1:e1m1/tech04_1 q2:e1u1/floor3_1" in said;
    # A folder of Quake's sounds written out whole; a game or a folder that is not there writes nothing.
    extracts = [line for line in said if line.startswith("extracted folder ")];
    assert len(extracts) == 2 and extracts[1].endswith("files=0 bytes=0") , str(extracts);
    wrote = int(extracts[0].split("files=")[1].split()[0]);
    assert extracts[0].startswith("extracted folder q1:sound/doors/ ") and wrote >= 10 and len(written) == wrote , str(extracts);
    assert all([name.startswith("q1/sound/doors/") and name.endswith(".wav") for name in written]) , str(written[:3]);
    assert sizes == int(extracts[0].split("bytes=")[1]) , str(sizes);
    source = repo / "finds_shelf.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "finds_shelf.png");
    source.unlink();
    print(
        f"FINDS PASS: {len(steps) - 1} steps, a map imported as a group, {count} materials found by name, those lately "
            + f"in hand listed, and {wrote} files of a folder written out"
    );
}

"""The sixtieth session: faces tilted to whole angles and laid through whole points."""
def whole_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-whole-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/whole_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "whole.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The whole session failed: {output / 'whole.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "tilted", "whole", "undone", "brush"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'whole.log'}";
    }
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    undone = [int(steps[name][0].split("undo=")[1].split()[0]) for name in names];
    # A ramp 96 long and 40 high. Its upright side stands at whole angles; its slope is tilted to one,
    # as one step; asked again there is nothing to tilt.
    assert brush_box(brushes(steps["made"])[0]) == [[-32, 112, 0], [32, 208, 40]] and "sides=5" in brushes(steps["made"])[0];
    tilts = [line for line in said if line.startswith("faceangle ")];
    assert tilts[:3] == [
        "faceangle faces=0 step=15.0 refused=0", "faceangle faces=1 step=15.0 refused=0", "faceangle faces=0 step=15.0 refused=0"
    ] , str(tilts);
    assert undone[1] == undone[0] + 1 , str(undone);
    # Turned about its middle its corners are off whole numbers: laid through whole points, as another
    # step; asked again there is nothing astray.
    lays = [line for line in said if line.startswith("integral ")];
    astray = float(lays[0].split("astray=")[1].split()[0]);
    assert lays[0].startswith("integral faces=1 ") and 0.01 < astray < 1.0 and lays[1] == "integral faces=0 astray=0.0 refused=0" , str(lays);
    assert undone[2] == undone[1] + 1 and undone[3] == undone[0] , str(undone);
    # One of the two done again; then with the brush selected every face is asked, and the one needs it.
    assert lays[2] == lays[0] and undone[4] == undone[2] , str(lays);
    mended = brush_box(brushes(steps["brush"])[0]);
    assert mended[0][2] == 0 and mended[1][1] == 208 and mended != [[-32, 112, 0], [32, 208, 40]] and "sides=5" in brushes(steps["brush"])[0];
    # With nothing picked or selected neither does anything.
    assert len(lays) == 3 and len(tilts) == 3 , str(lays) + str(tilts);
    print(
        f"WHOLE PASS: {len(steps) - 1} steps, a slope tilted to a whole angle and laid through whole points, each a "
            + "step, and a brush's faces asked together"
    );
}

"""The sixty-first session: how the explorer's model is played and drawn, and a box kept as a part."""
def playview_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "playview_fronts.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-playview-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/playview_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "playview.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The playview session failed: {output / 'playview.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = [
        "shown", "ranged", "round", "once", "playing", "fronts", "plain", "running", "boxed", "low_box", "high_box", "picked_box"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'playview.log'}";
    }
    shown: dict[str, str] = {};
    views: dict[str, str] = {};
    for name in names {
        # What the commands after a step print comes before the next step: only the line under the
        # model's own is the step's.
        place = [index for (index, line) in enumerate(steps[name]) if line.startswith("model ")][0];
        shown[name] = steps[name][place];
        under = steps[name][place + 1] if place + 1 < len(steps[name]) else "";
        views[name] = under if under.startswith("modelview ") else "";
    }
    # As it is shown at first nothing is said of how it is played: all its frames, ten a second.
    frames = int(shown["shown"].split("frames=")[1].split()[0]);
    edges = int(shown["shown"].split("edges=")[1].split()[0]);
    assert frames > 20 and views["shown"] == "" and " frame=0 " in shown["shown"];
    # Given frames eight to fourteen it comes in at the first; stepped on from the last it is at the
    # first again, and told to play once it stays on the last.
    assert " frame=8 " in shown["ranged"] and views["ranged"].startswith("modelview fps=30.0 range=8..14 loops=1 ");
    assert " frame=8 " in shown["round"] and " frame=14 " in shown["once"] and " loops=0 " in views["once"];
    assert " playing=1" in shown["playing"] and " frame=" in shown["playing"];
    # Without the faces turned away there are fewer edges to draw, and every point is ticked.
    fronts = int(views["fronts"].split("edges=")[1]);
    assert " backs=0 ticks=2.0 " in views["fronts"] and 0 < fronts < edges and f"edges={fronts} " in shown["fronts"] , views["fronts"];
    # Put back, nothing is said of it again; what is not an answer changes nothing.
    assert views["plain"] == "" and f"edges={edges} " in shown["plain"] and " frame=0 " in shown["plain"];
    said = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: ")];
    # The legs of a Quake III player play what its table gives the legs: running is found there with
    # its frames and its speed and goes round; the torso's shot is not the legs' to play. Three
    # frames are drawn between each two.
    offered = [line for line in said if line.startswith("clips sarge legs: ")][0].split(": ")[1].split();
    assert len(offered) == 18 and "run" in offered and "death1" in offered and "attack" not in offered , offered;
    clips = [line for line in said if line.startswith("clip ")];
    assert len(clips) == 1 and clips[0].startswith("clip run frames=") and clips[0].endswith(" loops=1") , clips;
    span = clips[0].split("frames=")[1].split()[0].split("..");
    rate = clips[0].split("fps=")[1].split()[0];
    assert int(span[1]) > int(span[0]) > 63 and f" frame={span[0]} " in shown["running"] and "sarge/lower.md3" in shown["running"];
    assert views["running"].startswith(f"modelview fps={rate} range={span[0]}..{span[1]} loops=1 smooth=1 between=3 ") , views["running"];
    # A model of two frames, the second sixteen higher: its box at each frame is a part of eight
    # points and twelve triangles, as high as the model stands at that frame.
    assert "boxpart frames=2 low=-32,-32,0 high=32,32,96" in said;
    low = [line for line in steps["low_box"] if line.startswith("modeldoc ")][0];
    high = [line for line in steps["high_box"] if line.startswith("modeldoc ")][0];
    assert " parts=2 part=1 " in low and " points=8 triangles=12 " in low and " open=0 " in low and "volume=393216 " in low , low;
    assert "low=-32,-32,0 high=32,32,96" in low and "low=-32,-32,16 high=32,32,112" in high and "volume=393216 " in high , high;
    # Asked for with nothing picked, no box is made; round one wall of the cylinder it is a thin one,
    # a part named for the part it was measured from.
    assert len([line for line in said if line.startswith("boxpart ")]) == 2 and "boxpart frames=2 low=23,0,0 high=32,23,96" in said;
    assert "part 2 bbox_cylinder triangles=12 in hand" in said;
    thin = [line for line in steps["picked_box"] if line.startswith("modeldoc ")][0];
    assert " parts=3 part=2 " in thin and " points=8 triangles=12 " in thin and " open=0 " in thin , thin;
    assert 20000 < int(thin.split("volume=")[1].split()[0]) < 21000 , thin;
    source = repo / "playview_fronts.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "playview_fronts.png");
    source.unlink();
    print(
        f"PLAYVIEW PASS: {len(steps) - 1} steps, a range of a model's {frames} frames stepped round and once, "
            + f"{fronts} of {edges} edges drawn without the faces turned away, sarge's legs running through frames "
            + f"{span[0]} to {span[1]} at {rate} a second, and a box part for each frame of a model and of one wall of it"
    );
}

"""The sixty-second session: a model kept in a work file, and written as Quake's and Quake II's own."""
def modelfiles_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "modelfiles_quake.png").unlink(missing_ok=True);
    heads: dict[str, bytes] = {};
    beside: list[str] = [];
    with tempfile.TemporaryDirectory(prefix="qp-modelfiles-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/modelfiles_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "modelfiles.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The model files session failed: {output / 'modelfiles.log'}";
        beside = sorted([found.name for found in Path(home + "/models").iterdir()]);
        for name in ["keep.qpm", "keep.mdl", "keep.md2"] {
            heads[name] = (Path(home + "/models") / name).read_bytes()[:64];
        }
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "closed", "work", "quake", "second"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'modelfiles.log'}";
    }
    docs: dict[str, str] = {};
    bones: dict[str, list[str]] = {};
    skins: dict[str, str] = {};
    for name in ["made", "work", "quake", "second"] {
        docs[name] = [line for line in steps[name] if line.startswith("modeldoc ")][0];
        bones[name] = [line for line in steps[name] if line.startswith("bone ") or line.startswith("bones ")];
        skins[name] = [line for line in steps[name] if line.startswith("skin ")][0];
    }
    # As it was made: two frames with the second in hand, the top picked, a tag, two bones.
    assert " parts=1 part=0 frames=2 frame=1:raised points=18 triangles=32 picked=9/8 " in docs["made"] , docs["made"];
    assert " tags=1 " in docs["made"] and len(bones["made"]) == 3 and bones["made"][0].startswith("bones 2 ");
    whole = int(docs["made"].split("volume=")[1].split()[0]);
    # Three files are written (and nothing as a kind of file this does not write). The games' files
    # keep no bones, so theirs lie beside them; the work file has its own inside it.
    saved = [line for line in ran.stdout.splitlines() if line.startswith("studio: saved model ")];
    assert len(saved) == 3 and beside == ["keep.md2", "keep.md2.rig", "keep.mdl", "keep.mdl.rig", "keep.qpm"] , beside;
    assert heads["keep.qpm"].startswith(b"qpmodel 1\nmodel cylinder\nhand 1 0\npart cylinder\n");
    assert heads["keep.mdl"][:4] == b"IDPO" and heads["keep.md2"][:4] == b"IDP2";
    assert len([line for line in steps["closed"] if line.startswith("modeldoc ")]) == 0;
    # The work file opens as the model was left, but for its undo list: the frame and pick in hand,
    # the tag, and the bones with what each carries.
    assert docs["work"] == docs["made"].replace(" undo=1 ", " undo=0 ") and bones["work"] == bones["made"] , docs["work"];
    # Quake's file is one mesh of both frames, a point a byte an axis: within a hundredth of the
    # volume. Its skin was inside it, and is the skin in hand in place of the small one made before.
    for (name, part) in [("quake", "mdl"), ("second", "md2")] {
        assert " keep parts=1 part=0 frames=2 frame=0:frame_0 points=18 triangles=32 picked=0/0 " in docs[name] , docs[name];
        assert " open=0 low=-32,-32,0 high=32,32,96 tags=0 " in docs[name] , docs[name];
        assert abs(int(docs[name].split("volume=")[1].split()[0]) - whole) < whole // 100 , docs[name];
        assert skins[name].startswith(f"skin part={part} placed=1 ") , skins[name];
    }
    assert " image=64x32 " in skins["quake"] and " skins=1 " in docs["quake"] , skins["quake"];
    source = repo / "modelfiles_quake.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "modelfiles_quake.png");
    source.unlink();
    print(
        f"MODELFILES PASS: {len(steps) - 1} steps, a model of two frames, a tag and two bones kept in a work file and "
            + "opened as it was left, and written as Quake's MDL with its skin and as Quake II's MD2 and read back"
    );
}

"""The sixty-third session: where a map's logic leaves a player stuck, and a side's bits by name."""
def stuck_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-stuck-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/stuck_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "stuck.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The stuck session failed: {output / 'stuck.log'}";
    }
    # What a command prints comes before the step that follows it: gathered here under that step.
    said: dict[str, list[str]] = {};
    pending: list[str] = [];
    for line in ran.stdout.splitlines() {
        if line.startswith("STEP ") {
            said[line[5:].strip()] = pending;
            pending = [];
        } elif line.startswith("studio: ") {
            pending.append(line[8:]);
        }
    }
    names = ["sound", "dead", "short", "counted", "keyless", "keyed", "named", "renamed", "third"];
    for name in names {
        assert name in said , f"The session never reached '{name}': {output / 'stuck.log'}";
    }
    stuck: dict[str, list[str]] = {};
    sides: dict[str, list[str]] = {};
    for name in names {
        stuck[name] = [line[8:] for line in said[name] if line.startswith("finding ")];
        sides[name] = [line[9:] for line in said[name] if line.startswith("sidebits ")];
    }
    # A button, a relay and a door in a row: nothing hangs and nothing is stuck.
    assert stuck["sound"] == [] , stuck["sound"];
    # Without the button the relay is the audit's to name, and the door behind it a softlock.
    assert stuck["dead"] == [
        "trigger_relay (pass) waits for pass, which nothing fires",
        "func_door (door1) is never set off: what fires it (trigger_relay (pass)) is never set off itself"
    ] , stuck["dead"];
    # A counter of three fired by two deaths: the door is reached now, the count never made; a
    # trigger that can be walked into again makes it up.
    assert stuck["short"] == ["trigger_counter (tally) counts to 3, and only 2 things ever fire it, once each"] , stuck["short"];
    assert stuck["counted"] == [] and stuck["keyed"] == [] , stuck["counted"];
    assert stuck["keyless"] == ["trigger_key wants key_data_cd, and this level has none (unless it is carried in from another)"];
    # A scene is of no one game: its sides' bits go by Quake II's names until told otherwise.
    assert [line for line in said["named"] if line.startswith("bits q2 flags ")] == [
        "bits q2 flags light slick sky warp trans33 trans66 flowing nodraw hint skip"
    ];
    assert len([line for line in said["named"] if line.startswith("bits q2 contents solid window aux lava ")]) == 1;
    assert sides["named"] == ["q2 contents=monsterclip,ladder flags=slick value=0"] , sides["named"];
    # One name off again; a name Quake II has not got changes nothing, and is taken as Quake III's
    # when said to be (a bit Quake II has no name for is given by its number).
    assert sides["renamed"] == [
        "q2 contents=ladder flags=slick value=0", "q2 contents=ladder,2147483648 flags=slick value=0"
    ] , sides["renamed"];
    # The same numbers as Quake III reads them: its bit twenty-nine is another thing.
    assert len([line for line in said["third"] if line.startswith("bits q3 contents solid lava slime water fog ")]) == 1;
    assert sides["third"] == ["q3 contents=translucent,nodrop flags=slick value=0"] , sides["third"];
    print(
        f"STUCK PASS: {len(names)} steps, a door behind a relay nothing sets off, a counter of three with two to fire it "
            + "and a lock with no key found and put right, and a brush's sides flagged by Quake II's names and read by Quake III's"
    );
}

"""The sixty-fourth session: linked prefabs turned and sized where they stand."""
def turned_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "turned_bench.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-turned-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/turned_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_PREFABS");
        (output / "turned.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The turned session failed: {output / 'turned.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = [
        "linked", "plain", "turned", "turned_plain", "sized", "sized_plain", "long", "long_plain", "again", "tipped",
        "tipped_plain", "level"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'turned.log'}";
    }
    # The instance says how it differs from its file; one entity, built as the floor and the bench.
    held: dict[str, str] = {};
    for name in ["linked", "turned", "sized", "long", "again", "tipped", "level"] {
        assert len(selected(steps[name])) == 1 and made(steps[name]) == 2 , str(steps[name]);
        held[name] = selected(steps[name])[0];
    }
    assert held["linked"].endswith("classname=misc_prefab prefab=bench origin=0 128 0") , held["linked"];
    # Sixty degrees and thirty more: a quarter round. Twice as large; a size of nothing or of no number changes nothing.
    assert held["turned"].endswith("origin=0 128 0 angle=90") and held["sized"].endswith("angle=90 _scale=2") , held["sized"];
    assert held["long"].endswith("angle=90 _scale=2 1 1") and held["again"] == held["linked"] , held["again"];
    # Turned into plain brushes it lies where the instance stood it: ninety-six long along x as its
    # file has it; along y when turned; twice the size about its origin, its underside still on the
    # floor; and with only its own length doubled, the length that now runs along y.
    lies: dict[str, str] = {};
    for name in ["plain", "turned_plain", "sized_plain", "long_plain", "tipped_plain"] {
        boxes = [line.split(" sides=")[0].split(" low=")[1] for line in steps[name] if line.startswith("brush #")];
        assert len(boxes) == 1 and made(steps[name]) == 2 and len(selected(steps[name])) == 0 , str(steps[name]);
        lies[name] = boxes[0];
    }
    assert lies["plain"] == "-48,112,0 high=48,144,16" and lies["turned_plain"] == "-16,80,0 high=16,176,16" , str(lies);
    assert lies["sized_plain"] == "-32,32,0 high=32,224,32" and lies["long_plain"] == "-16,32,0 high=16,224,16" , str(lies);
    # Tipped nose down a quarter (and not turned a way that is no way): its length hangs through the
    # floor from where it stands, and it is level again when put back.
    assert held["tipped"].endswith("origin=0 128 0 angles=90 0 0") and held["level"] == held["linked"] , held["tipped"];
    assert lies["tipped_plain"] == "0,112,-48 high=16,144,48" , str(lies);
    source = repo / "turned_bench.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "turned_bench.png");
    source.unlink();
    print(
        f"TURNED PASS: {len(steps) - 1} steps, a linked bench turned a quarter round, made twice as large and made longer "
            + "where it stands and tipped nose down, each seen as the plain brushes it stands for, and put back as its file has it"
    );
}

"""The sixty-fifth session: a WAD's lumps in the explorer, and archives changed in place."""
def repack_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    import struct;
    import zipfile;
    (repo / "repack_lump.png").unlink(missing_ok=True);
    work = repo / ".jac/studio-repack";
    shutil.rmtree(work, ignore_errors=True);
    (work / "seed").mkdir(parents=True);
    (work / "seed/note.txt").write_text("a note\n");
    (work / "seed/wall.txt").write_text("the wall, in words\n");
    (work / "seed/floor.txt").write_text("floor\n");
    # Quake read from a copy of its archives, so that the game's own are never the ones at stake.
    quake = Path(env.get("QP_ASSETS", "") or (os.getenv("HOME", "") + "/quake-assets/id1"));
    (work / "id1").mkdir();
    for found in sorted(quake.iterdir()) {
        if found.name.lower().endswith(".pak") {
            shutil.copyfile(found, work / "id1" / found.name);
        }
    }
    before = (work / "id1/pak0.pak").read_bytes();
    kept_assets = env.get("QP_ASSETS", "");
    with tempfile.TemporaryDirectory(prefix="qp-repack-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_EXTRACT"] = str(work / "extract");
        env["QP_ASSETS"] = ".jac/studio-repack/id1";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/repack_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_EXTRACT");
        if kept_assets {
            env["QP_ASSETS"] = kept_assets;
        } else {
            env.pop("QP_ASSETS");
        }
        (output / "repack.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The repack session failed: {output / 'repack.log'}";
    }
    said: dict[str, list[str]] = {};
    pending: list[str] = [];
    for line in ran.stdout.splitlines() {
        if line.startswith("STEP ") {
            said[line[5:].strip()] = pending;
            pending = [];
        } elif line.startswith("studio: ") {
            pending.append(line[8:]);
        }
    }
    steps = studio_steps(ran.stdout);
    for name in ["lump", "letters", "made", "changed", "zipped", "kept"] {
        assert name in steps and name in said , f"The session never reached '{name}': {output / 'repack.log'}";
    }
    # A lump of Quake's gfx.wad is a file in a folder: the status bar as the picture it is, written
    # out as the WAD has it (its size, then a byte a texel); the console's letters as a sheet.
    lump = [line for line in steps["lump"] if line.startswith("asset ")];
    assert lump == ["asset q1:gfx.wad/sbar kind=image size=7688 note=320x24 lines=0 material="] , str(lump);
    written = (work / "extract/q1/gfx.wad/sbar").read_bytes();
    assert len(written) == 7688 and struct.unpack("<ii", written[:8]) == (320, 24) and "studio: extracted 7688 bytes" in ran.stdout;
    letters = [line for line in steps["letters"] if line.startswith("asset ")];
    assert letters == ["asset q1:gfx.wad/conchars kind=image size=16384 note=128x128 lines=0 material="] , str(letters);
    # A PAK made a file at a time holds the three under the names given.
    assert [line for line in said["made"] if line.startswith("packed ")] == [
        "packed note.txt 7", "packed textures/yard/wall.txt 19", "packed textures/yard/floor.txt 6"
    ] , str(said["made"]);
    assert len([line for line in said["made"] if line.startswith("archive yard.pak files=") and " add=" in line]) == 3;
    # The note replaced by the wall's words under its own name, the folder gone, nothing else changed.
    changes = [line for line in said["changed"] if line.startswith("archive ") and (" add=" in line or " drop=" in line)];
    assert len(changes) == 2 and changes[0].endswith("add=NOTE.TXT was=3") and " files=3 " in changes[0] , str(changes);
    assert changes[1].endswith("drop=textures/ was=3") and " files=1 " in changes[1] , str(changes);
    pak = (work / "yard.pak").read_bytes();
    where = struct.unpack("<ii", pak[4:12]);
    start = int(where[0]);
    size = int(where[1]);
    assert pak[:4] == b"PACK" and size == 64 and pak[start:start + 8] == b"note.txt" and pak[12:31] == b"the wall, in words\n";
    # The PK3: one name put in twice is one file with the later contents, and the other dropped.
    with zipfile.ZipFile(work / "yard.pk3") as packed {
        assert packed.namelist() == ["scripts/note.txt"] and packed.read("scripts/note.txt") == b"floor\n" and packed.testzip() is None;
    }
    assert [line for line in said["zipped"] if line.startswith("packed ")] == ["packed scripts/note.txt 6"] , str(said["zipped"]);
    # What is not an archive, or is not there, is listed as nothing; Quake's own PAK (here a copy the
    # run reads the game from) is refused twice, still listed, and not a byte of it changed.
    assert len([line for line in said["zipped"] if line.startswith("archive none.pak") or line.startswith("archive note.txt")]) == 0;
    assert [line for line in said["kept"] if "refused" in line] == ["archive pak0.pak refused", "archive pak0.pak refused"] , str(said["kept"]);
    listed = [line for line in said["kept"] if line.startswith("archive pak0.pak files=")];
    assert len(listed) == 1 and int(listed[0].split("files=")[1].split()[0]) > 300 , str(listed);
    assert (work / "id1/pak0.pak").read_bytes() == before and not (work / "id1/pak0.pak.new").exists();
    source = repo / "repack_lump.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "repack_lump.png");
    source.unlink();
    shutil.rmtree(work, ignore_errors=True);
    print(
        f"REPACK PASS: {len(steps) - 1} steps, the status bar and the console's letters shown from Quake's gfx.wad and one "
            + "written out, a PAK and a PK3 made a file at a time with a file replaced and a folder dropped, and a game's own "
            + "PAK left as it was"
    );
}

"""The sixty-sixth session: files found by kind, game and tag, a texture's details, materials of a size."""
def finding_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    kept = "";
    with tempfile.TemporaryDirectory(prefix="qp-finding-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/finding_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "finding.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The finding session failed: {output / 'finding.log'}";
        kept = (Path(home) / "overrides/asset_tags.txt").read_text();
    }
    # What a command prints comes before the step that follows it: gathered here under that step.
    said: dict[str, list[str]] = {};
    pending: list[str] = [];
    for line in ran.stdout.splitlines() {
        if line.startswith("STEP ") {
            said[line[5:].strip()] = pending;
            pending = [];
        } elif line.startswith("studio: ") {
            pending.append(line[8:]);
        }
    }
    names = [
        "pictures", "sounds", "models", "nothing", "tagged", "tagged_models", "untagged", "known", "square", "large", "all"
    ];
    for name in names {
        assert name in said , f"The session never reached '{name}': {output / 'finding.log'}";
    }
    found: dict[str, int] = {};
    for name in ["pictures", "sounds", "models", "nothing", "tagged", "tagged_models", "untagged"] {
        counts = [int(line.split()[1]) for line in said[name] if line.startswith("found ")];
        assert len(counts) >= 1 , f"No search answered at '{name}'";
        found[name] = counts[-1];
    }
    # Quake II's pictures named for metal are many; sounds named for a menu a few; Quake has one model
    # named for a soldier; and a kind that is none finds nothing.
    assert found["pictures"] > 50 and 1 <= found["sounds"] < 40 and found["models"] == 1 and found["nothing"] == 0 , str(found);
    # Two files tagged with one word are found by it, one of them when a kind is asked as well; the
    # tag taken off is found on nothing. A tag of more than a word was not kept.
    assert found["tagged"] == 2 and found["tagged_models"] == 1 and found["untagged"] == 0 , str(found);
    assert kept == "q1:progs/soldier.mdl grunt\nq2:textures/e1u1/metal1_1.wal grunt\n" , kept;
    assert "tags q2:textures/e1u1/metal1_1.wal grunt trim" in said["tagged"] and "tagged q1:progs/soldier.mdl grunt" in said["tagged"];
    # A texture of each game: Quake II's with its flags and contents by name, Quake's sliding
    # texture as one of seven frames, a plain one as one, Quake III's by its true size.
    facts: dict[str, str] = {};
    for line in said["known"] {
        if line.startswith("texinfo ") {
            facts[line.split()[1]] = line;
        }
    }
    assert len(facts) == 4 , str(facts);
    assert " size=64x64 flags=none contents=none value=0 next=none frames=1 colours=" in facts["q2:e1u1/metal1_1"] , str(facts);
    assert " size=64x64 frames=7 colours=" in facts["q1:e1m1/+0slip"] and " size=128x16 frames=1 " in facts["q1:e1m1/tech04_1"];
    assert " size=256x512 shader=" in facts["q3:textures/base_wall/archpipe2_k_tall3fin"] , str(facts);
    assert 1 < int(facts["q1:e1m1/tech04_1"].split("colours=")[1].split()[0]) <= 256;
    # The level's textures of one size are some of them, and those named for tech and large are fewer.
    square = [line for line in said["square"] if line.startswith("sized 64x64 ")];
    large = [line for line in said["large"] if line.startswith("sized >=128 ")];
    assert len(square) >= 1 and len(large) >= 1 , str(said["square"]);
    whole = int(square[-1].split(" of ")[1]);
    some = int(square[-1].split("shown=")[1].split()[0]);
    fewer = int(large[-1].split("shown=")[1].split()[0]);
    assert whole > 40 and 0 < some < whole and 0 < fewer < some , f"{square} {large}";
    assert len([line for line in said["all"] if line.startswith("sized ")]) == 0;
    print(
        f"FINDING PASS: {len(names)} steps, {found['pictures']} of Quake II's pictures named for metal and one soldier among "
            + f"Quake's models found, two files found by a tag, a texture of each game told of, and {some} of {whole} of a "
            + f"level's textures at 64 by 64"
    );
}

"""The sixty-seventh session: a box drawn in the 3D view, and the scene tree said in words."""
def treebox_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-treebox-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/treebox_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "treebox.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The treebox session failed: {output / 'treebox.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["bare", "drawn", "again", "sky", "grouped"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'treebox.log'}";
    }
    counts: dict[str, int] = {};
    for name in ["bare", "drawn", "again", "sky", "grouped"] {
        counts[name] = int([line for line in steps[name] if line.startswith("brushes=")][0].split("=")[1].split()[0]);
    }
    # A drag across the floor in the one 3D view makes one brush: on the grid, standing on the floor,
    # sixty-four high, with some width and depth.
    drawn = [line for line in steps["drawn"] if line.startswith("brush #")];
    assert counts["bare"] == 1 and counts["drawn"] == 2 and len(drawn) == 1 and "mode=draw " in steps["drawn"][-1] , str(steps["drawn"]);
    box = brush_box(drawn[0]);
    assert box[0][2] == 0 and box[1][2] == 64 and box[1][0] - box[0][0] >= 16 and box[1][1] - box[0][1] >= 16 , drawn[0];
    assert all([value % 16 == 0 for value in box[0] + box[1]]) , drawn[0];
    # It lies under where the drag was: ahead of the camera, which stands at y -420 looking along +y.
    assert box[0][1] > -420 and box[0][0] < 0 < box[1][0] , drawn[0];
    # The same rectangle by command is the same box; one that ends in the sky is none.
    again = [line for line in steps["again"] if line.startswith("brush #")];
    assert counts["again"] == 3 and len(again) == 1 and brush_box(again[0]) == box , str(again);
    assert counts["sky"] == 3 and len([line for line in steps["sky"] if line.startswith("brush #")]) == 0;
    # The tree in words: the group is a row under its class, marked as the duplicator it is.
    rows = [line[12:] for line in ran.stdout.splitlines() if line.startswith("studio: row ")];
    marked = [row for row in rows if "posts  (duplicator: 3 copies and mirrored)" in row];
    assert len(marked) == 2 and marked[0].startswith("1 ") and marked[0].endswith("[1] *") , str(rows);
    assert len([row for row in rows if row.startswith("0 class:func_group func_group")]) == 1 and len(rows) == 6 , str(rows);
    assert len([row for row in rows if row.startswith("0 class:brushes brushes [4]")]) == 1 , str(rows);
    print(
        f"TREEBOX PASS: {len(steps) - 1} steps, a box {box[1][0] - box[0][0]} by {box[1][1] - box[0][1]} by 64 drawn on the "
            + "floor by a drag in the 3D view and again by command, a drag into the sky refused, and a duplicator named in "
            + "the scene tree"
    );
}

"""The sixty-eighth session: a model's triangles cut along a plane, and a tag turned."""
def meshcut_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "meshcut_cut.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-meshcut-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/meshcut_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "meshcut.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The meshcut session failed: {output / 'meshcut.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "cut", "cut_short", "undone", "turned"];
    docs: dict[str, str] = {};
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'meshcut.log'}";
        docs[name] = [line for line in steps[name] if line.startswith("modeldoc ")][0];
    }
    def number(line: str, key: str) -> int {
        return int(line.split(" " + key + "=")[1].split()[0]);
    }
    # A cylinder of eight sides: sixteen triangles of wall and sixteen of caps, at two frames.
    assert " frames=2 frame=1:tall points=18 triangles=32 " in docs["made"] and " open=0 " in docs["made"] , docs["made"];
    # Cut across its height: each wall triangle becomes three, with a new point on each of the eight
    # upright sides and each of the eight diagonals; it is closed still and holds what it held.
    assert number(docs["cut"], "points") == 34 and number(docs["cut"], "triangles") == 64 and " open=0 " in docs["cut"] , docs["cut"];
    assert number(docs["cut"], "volume") == number(docs["made"], "volume") and number(docs["cut"], "undo") == 2;
    # The other frame has the same triangles and its own volume: the cut fell on both alike.
    assert " frame=0:" in docs["cut_short"] and number(docs["cut_short"], "triangles") == 64 and " open=0 " in docs["cut_short"];
    assert 0 < number(docs["cut_short"], "volume") < number(docs["cut"], "volume");
    # A plane that misses is no edit; undone, the model is as it was made.
    assert number(docs["undone"], "triangles") == 32 and number(docs["undone"], "points") == 18 and number(docs["undone"], "undo") == 1;
    # The tag turned a quarter about the upright at one frame, tipped at both, and half round at
    # the other: what it faces at each, a line a turn (a turn of nothing and of no tag say nothing).
    faced = [line[8:] for line in ran.stdout.splitlines() if line.startswith("studio: tagaxes ")];
    assert faced == [
        "tagaxes tag_top frame=0 0.0,1.0,0.0 -1.0,0.0,0.0 0.0,0.0,1.0",
        "tagaxes tag_top frame=0 0.0,0.0,1.0 -1.0,0.0,0.0 0.0,-1.0,0.0",
        "tagaxes tag_top frame=1 -1.0,0.0,0.0 0.0,0.0,1.0 0.0,1.0,0.0"
    ] , str(faced);
    assert " tags=1 " in docs["turned"] and number(docs["turned"], "triangles") == 64;
    source = repo / "meshcut_cut.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "meshcut_cut.png");
    source.unlink();
    print(
        f"MESHCUT PASS: {len(steps) - 1} steps, a cylinder's sixteen wall triangles cut into forty-eight along a plane at both "
            + "frames, closed and of the same volume, undone and done again, and a tag turned at one frame and at all"
    );
}

"""The forty-ninth session: a shipped level's entities listed and drawn as
their game's models."""
def preview_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "preview_models.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-preview-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/preview_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "preview.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The preview session failed: {output / 'preview.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in ["boxes", "models", "off"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'preview.log'}";
    }
    # The level's monsters and pickups each have the model their game gives them.
    listed = [line for line in steps["boxes"] if line.startswith("model of ")];
    known = [line for line in steps["boxes"] if line.startswith("models known=")];
    assert known and int(known[0].split("=")[1]) == len(listed) and len(listed) >= 30 , str(known);
    soldiers = [line for line in listed if line.startswith("model of monster_army q1:progs/soldier.mdl edges=")];
    assert soldiers and int(soldiers[0].split("edges=")[1]) > 100 , str(listed[:4]);
    assert [line for line in listed if line.startswith("model of item_armor1 q1:progs/armor.mdl ")];
    assert not [line for line in steps["boxes"] if line.startswith("models shown=")];
    # Drawn in the 3D view near the camera; and not once it is turned off.
    shown = [line for line in steps["models"] if line.startswith("models shown=1 drawn=")];
    assert shown and int(shown[0].split("drawn=")[1]) >= 1 , str(steps["models"]);
    assert not [line for line in steps["off"] if line.startswith("models shown=")] and "ed_models off" in kept;
    source = repo / "preview_models.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "preview_models.png");
    source.unlink();
    print(
        f"PREVIEW PASS: {len(steps) - 1} steps, {len(listed)} entities of a shipped level given their game's models, "
            + f"{shown[0].split('drawn=')[1]} of them drawn in the 3D view"
    );
}

"""A step's `skin` line, the dump's own."""
def skin_line(lines: list[str]) -> str {
    found = [line for line in lines if line.startswith("skin part=")];
    return found[0] if found else "";
}

"""The forty-eighth session: a part laid on its skin and its places changed,
a picture painted on the skin and through the model, shown and saved."""
def skin_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "skin_view.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-skin-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/skin_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "skin.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The skin session failed: {output / 'skin.log'}";
        picture = (Path(home) / "models/tower.tga").read_bytes();
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "laid", "shaped", "turned", "dabbed", "painted", "saved"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'skin.log'}";
    }
    # Laid flat into the left half of the skin; then half the size, a quarter across.
    assert " box=0.0,0.0,0.5,1.0 " in skin_line(steps["laid"]) , skin_line(steps["laid"]);
    assert " box=0.375,0.25,0.625,0.75 " in skin_line(steps["shaped"]) , skin_line(steps["shaped"]);
    # A quarter turn swaps how wide and tall it lies; the flip after it was undone.
    assert " box=0.25,0.375,0.75,0.625 " in skin_line(steps["turned"]) , skin_line(steps["turned"]);
    assert model_word(steps["turned"], "undo") == "4" , str(steps["turned"]);
    # A picture, a dab on the skin, and a dab where a click on the model lands on it.
    assert " image=64x64 dabs=1 " in skin_line(steps["dabbed"]) and " image=64x64 dabs=2 " in skin_line(steps["painted"]);
    landed = [line for line in steps["dabbed"] if line.startswith("painted at ")];
    assert len(landed) == 1 , str(steps["dabbed"]);
    place = [float(part) for part in landed[0][11:].split(",")];
    assert 0.25 <= place[0] and place[0] <= 0.75 and 0.375 <= place[1] and place[1] <= 0.625 , str(place);
    assert model_word(steps["painted"], "pick") == "paint" and " shown=1" in skin_line(steps["saved"]);
    # The saved picture: red where it was dabbed on the skin, green where the click landed, grey elsewhere.
    assert len(picture) == 18 + 64 * 64 * 4 and picture[2] == 2;
    texel = tga_texel(picture, int(0.9 * 64), int(0.9 * 64));
    assert texel == [255, 0, 0] , str(texel);
    assert tga_texel(picture, int(place[0] * 64), int(place[1] * 64)) == [0, 255, 0];
    assert tga_texel(picture, 2, 2) == [40, 40, 40];
    source = repo / "skin_view.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "skin_view.png");
    source.unlink();
    print(
        f"SKIN PASS: {len(steps) - 1} steps, a part laid flat on its skin, stretched, moved and turned there, and a picture "
            + f"painted on the skin and through the model at {place[0]}, {place[1]}"
    );
}

"""The colour of a texel of an uncompressed 32-bit TGA written top row first: [red, green, blue]."""
def tga_texel(data: bytes, x: int, y: int) -> list[int] {
    at = 18 + (y * 64 + x) * 4;
    return [data[at + 2], data[at + 1], data[at]];
}

"""The forty-seventh session: a prefab that holds prefabs, and an instance
that differs from its prefab."""
def nest_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "nest_gate.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-nest-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/nest_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_PREFABS");
        (output / "nest.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The nest session failed: {output / 'nest.log'}";
        gate = (Path(home) / "prefabs/gate.map").read_text();
        built = (Path(home) / "scenes/nesting.build.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    for name in ["parts", "bare", "gate", "differs", "written"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'nest.log'}";
    }
    # The gate is kept as two instances of the post, one with a swap of its own, and a lintel.
    parts = selected(steps["parts"]);
    assert len(parts) == 3 and "prefab=post" in parts[0] and "_swap=blockout slate" in parts[1] and "_group_name=lintel" in parts[2] , str(parts);
    assert gate.count('"classname" "misc_prefab"') == 2 and '"_swap" "blockout slate"' in gate;
    # With everything taken out only the floor is built; the gate linked in builds a lintel and two posts with it.
    assert made(steps["bare"]) == 1 and made(steps["gate"]) == 4 , str(steps["gate"]);
    assert len(selected(steps["gate"])) == 1 and "prefab=gate" in selected(steps["gate"])[0];
    # The instance's own swap changes what the gate left as it was; the post that was slate inside it stays slate.
    assert "_swap=blockout brass" in selected(steps["differs"])[0] and "_names=_north" in selected(steps["differs"])[0];
    sides = material_sides(built);
    assert sides == [12, 6, 6] , str(sides);
    assert "misc_prefab" not in built;
    source = repo / "nest_gate.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "nest_gate.png");
    source.unlink();
    print(
        f"NEST PASS: {len(steps) - 1} steps, a gate kept as a prefab of two posts and a lintel, built from one instance, "
            + "and the instance's material swapped over what the gate itself swapped"
    );
}

"""How many sides of a written map are brass, slate and blockout."""
def material_sides(text: str) -> list[int] {
    return [
        len([line for line in text.splitlines() if line.startswith("(") and " " + name + " [" in line])
        for name in ["brass", "slate", "blockout"]
    ];
}

"""The forty-sixth session: a sound converted, a wall texture's facts
changed in a copy, and animated textures' frames listed."""
def sounds_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-sounds-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_SOUNDS"] = home + "/sounds";
        env["QP_TEXTURES"] = home + "/textures";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/sounds_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_SOUNDS");
        env.pop("QP_TEXTURES");
        (output / "sounds.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The sounds session failed: {output / 'sounds.log'}";
        blip = (Path(home) / "sounds/blip.wav").read_bytes();
        quiet = (Path(home) / "sounds/quiet.wav").read_bytes();
        plate = (Path(home) / "textures/lab/plate.wal").read_bytes();
    }
    before = (repo / "scripts/studio/fixtures/plate.wal").read_bytes();
    steps = studio_steps(ran.stdout);
    for name in ["begin", "wal", "frames"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'sounds.log'}";
    }
    # Two channels at 44100 made one at the games' rates: 22050 at 16 bits, 11025 at 8.
    said = [line for line in steps["begin"] if line.startswith("sound ")];
    assert said[0] == "sound blip.wav 44100 Hz, 16 bits, 2 channels, 0.1 s" , str(said);
    assert said[1].startswith("sound blip.wav 22050 Hz, 16 bits, one channel, 0.1 s from ") , str(said);
    assert said[2].startswith("sound quiet.wav 11025 Hz, 8 bits, one channel, 0.1 s from ") , str(said);
    assert blip[:4] == b"RIFF" and int.from_bytes(blip[22:24], "little") == 1 and int.from_bytes(blip[24:28], "little") == 22050;
    assert int.from_bytes(blip[40:44], "little") == 2205 * 2 and int.from_bytes(quiet[24:28], "little") == 11025;
    assert int.from_bytes(quiet[34:36], "little") == 8;
    # The texture's facts as they were, and as changed in the copy: its pictures untouched.
    facts = [line for line in steps["wal"] if line.startswith("wal name=")];
    assert facts[0] == "wal name=lab/plate size=32x32 flags=0 names=- contents=0 value=0 next=-" , str(facts);
    assert facts[1] == "wal name=lab/plate size=32x32 flags=9 names=light,warp contents=0 value=300 next=lab/plate2" , str(facts);
    assert len(plate) == len(before) and plate[100:] == before[100:] and plate[:56] == before[:56];
    assert int.from_bytes(plate[88:92], "little") == 9 and int.from_bytes(plate[96:100], "little") == 300 and plate[56:66] == b"lab/plate2";
    # Quake's slipgate texture is a row of seven; a plain name is one.
    rows = [line for line in steps["frames"] if line.startswith("frames ")];
    assert rows[0].startswith("frames 7 q1:e1m1/+0slip q1:e1m1/+1slip ") and rows[1] == "frames 1 nothing_animated" , str(rows);
    print(
        f"SOUNDS PASS: {len(steps) - 1} steps, a stereo sound made one channel at 22050 and at 11025, a wall texture's "
            + "flags and value changed in a copy, and a row of seven animated frames found"
    );
}

"""A word of a step's `shaders` line: what follows `key=`."""
def shader_word(lines: list[str], key: str) -> str {
    found = [line for line in lines if line.startswith("shaders file=")];
    return found[0].split(" " + key + "=")[1].split()[0] if found else "";
}

"""The forty-fifth session: a shader script made, changed, checked, mended,
saved and opened again, and a broken one's faults listed."""
def shader_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "shader_faults.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-shader-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_SHADERS"] = home + "/scripts";
        (Path(home) / "scripts").mkdir();
        (Path(home) / "scripts/broken.shader").write_text(
            "textures/a\n{\n\tcull sideways\n\t{\n\t\tblendFunc add\n\t}\n\ntextures/b\n{\n}\n"
        );
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/shader_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_SHADERS");
        (output / "shader.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The shader session failed: {output / 'shader.log'}";
        written = (Path(home) / "scripts/keep.shader").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "shaped", "wrong", "mended", "reopened", "picked", "broken"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'shader.log'}";
    }
    # A new shader: a picture lit by the level's light, two stages.
    assert shader_word(steps["made"], "count") == "1" and shader_word(steps["made"], "stages") == "2";
    shown = [line[2:] for line in steps["made"] if line.startswith("| ")];
    assert shown[0] == "textures/keep/water" and "        map $lightmap" in shown , str(shown);
    # Three lines of its own, three stages, the added one first; and nothing the game would trip on.
    assert shader_word(steps["shaped"], "lines") == "3" and shader_word(steps["shaped"], "stages") == "3";
    shaped = [line[2:] for line in steps["shaped"] if line.startswith("| ")];
    assert shaped[5:8] == ["    {", "        map textures/keep/foam.tga", "        blendFunc add"] , str(shaped);
    assert "        tcMod scroll 0.2 0" in shaped and "        tcMod scroll 0.1 0.05" not in shaped and "        tcMod turb 0 0.2 0 0.1" in shaped;
    assert "shader faults 0" in steps["shaped"] , str(steps["shaped"]);
    # Two mistakes, each said; mended, none.
    faults = [line for line in steps["wrong"] if line.startswith("shader fault ")];
    assert len(faults) == 2 and "shader faults 2" in steps["wrong"] , str(steps["wrong"]);
    assert [line for line in faults if "A shader has no glitter" in line] and [line for line in faults if "stage 0: rgbGen takes one of" in line];
    assert "shader faults 0" in steps["mended"] and shader_word(steps["mended"], "lines") == "3";
    # What was saved is the script, a tab a brace, and it opens again as two shaders.
    assert written.startswith(
        "textures/keep/water\n{\n\tsurfaceparm trans\n\tsurfaceparm water\n\tcull none\n\t{\n\t\tmap textures/keep/foam.tga\n"
            + "\t\tblendFunc add\n\t\trgbGen identity\n\t}\n\t{\n\t\tmap $lightmap\n\t\trgbGen identity\n\t}\n"
    ) , written;
    assert "textures/keep/glow\n{\n" in written and written.count("\n}\n") == 2;
    assert shader_word(steps["reopened"], "count") == "2" and shader_word(steps["reopened"], "edited") == "0";
    listed = [line for line in steps["reopened"] if line.startswith("shader 0 ") or line.startswith("shader 1 ")];
    assert len(listed) == 2 and listed[0].startswith("shader 0 textures/keep/water lines=3 stages=3") , str(listed);
    assert shader_word(steps["picked"], "now") == "textures/keep/water";
    # A script broken by hand: what is wrong is said with the line it is at.
    broken = [line for line in steps["broken"] if line.startswith("shader fault ")];
    assert len(broken) >= 4 , str(steps["broken"]);
    assert [line for line in broken if line.startswith("shader fault line 1: The shader textures/a is not closed")] , str(broken);
    assert [line for line in broken if "cull takes one of" in line] and [line for line in broken if "has no picture" in line];
    source = repo / "shader_faults.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "shader_faults.png");
    source.unlink();
    print(
        f"SHADER PASS: {len(steps) - 1} steps, a shader made and shaped by lines and stages, two mistakes found and mended, "
            + f"the script saved and opened again, and a broken one's {len(broken)} faults said by line"
    );
}

"""The forty-fourth session: entities that carry their game, camp spots,
and the level played with what was placed spawned."""
def games_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "games_camps.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-games-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/games_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "games.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The games session failed: {output / 'games.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["health", "ogre", "stray", "filled", "spots", "playing"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'games.log'}";
    }
    # A pickup and a monster added to a scene of no one game carry their own.
    assert "classname=item_health" in selected(steps["health"])[0] and "asset_game=q1" in selected(steps["health"])[0];
    assert "classname=monster_ogre" in selected(steps["ogre"])[0] and "asset_game=q1" in selected(steps["ogre"])[0];
    # One left with none is found, and only it: a player start is every game's.
    assert "asset_game" not in selected(steps["stray"])[0] , str(selected(steps["stray"]));
    found = [line for line in steps["stray"] if line.startswith("finding ") and "carries no game" in line];
    assert len(found) == 1 and found[0].startswith("finding item_armor2 ") , str(steps["stray"]);
    assert "asset games set=1" in steps["stray"] , str(steps["stray"]);
    assert not [line for line in steps["filled"] if "carries no game" in line] , str(steps["filled"]);
    # Camp spots are listed with how far and how much.
    spots = [line for line in steps["spots"] if line.startswith("camp ")];
    assert len(spots) == 2 and spots[0].startswith("camp info_camp ") and spots[0].endswith("range=96 weight=2") , str(spots);
    assert "camps 2" in steps["spots"];
    # Played, they are spawned: the two pickups at least, and the ogre.
    live = [line for line in steps["playing"] if line.startswith("live pickups=")];
    assert live , str(steps["playing"]);
    pickups = int(live[0].split("pickups=")[1].split()[0]);
    opponents = int(live[0].split("opponents=")[1].split()[0]);
    assert pickups >= 2 and opponents == 1 , live[0];
    source = repo / "games_camps.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "games_camps.png");
    source.unlink();
    print(
        f"GAMES PASS: {len(steps) - 1} steps, entities carrying their game as they are added, one found without and "
            + f"given its class's, two spots for bots, and {pickups} pickups and {opponents} monster spawned in play"
    );
}

"""A terrain's heights from a step's dump."""
def heights_of(lines: list[str]) -> list[int] {
    found = [line for line in lines if line.startswith("selected ") and "_heights=" in line];
    return [int(float(word)) for word in found[0].split("_heights=")[1].split(" owns=")[0].split()] if found else [];
}

"""The forty-third session: fine work on a terrain."""
def touch_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "touch_plot.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-touch-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/touch_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "touch.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The touch session failed: {output / 'touch.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "terrace", "touched", "plot", "plotlift", "cleared", "pressed", "top", "bottom", "under", "both"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'touch.log'}";
    }
    # A terrace of fifteen corners at 32; touched, they all go up eight and the low ground stays.
    terrace = heights_of(steps["terrace"]);
    assert len(terrace) == 25 and terrace.count(32) == 15 and terrace.count(0) == 10 , str(terrace);
    assert "touched 15" in steps["terrace"] , str(steps["terrace"]);
    touched = heights_of(steps["touched"]);
    assert touched.count(40) == 15 and touched.count(0) == 10 , str(touched);
    # The plot: the four cells of the low ground; lifted, their ten corners go up sixteen.
    assert "plot cells=4" in steps["touched"] , str(steps["touched"]);
    lifted = heights_of(steps["plotlift"]);
    assert lifted.count(16) == 10 and lifted.count(40) == 15 , str(lifted);
    assert "plot painted 8" in steps["plotlift"] and "plot cells=0" in steps["plotlift"] , str(steps["plotlift"]);
    # Alt and a press in sculpt mode picks a plot where the pointer is.
    pressed = [line for line in steps["cleared"] if line.startswith("plot cells=")];
    assert pressed and int(pressed[0].split("=")[1]) > 0 , str(steps["cleared"]);
    # The top up eight; the underside down sixteen with the base that much thicker; then all of it up.
    top = heights_of(steps["top"]);
    assert top.count(24) == 10 and top.count(48) == 15 , str(top);
    assert "_terrain=4 4 64 32" in selected(steps["bottom"])[0] and heights_of(steps["bottom"]) == top , str(steps["bottom"]);
    under = brushes(steps["under"]);
    assert len(under) == 1 and brush_box(under[0])[0][2] == -16 , str(under);
    raised = brushes(steps["both"]);
    assert len(raised) == 1 and brush_box(raised[0])[0][2] == 16 and brush_box(raised[0])[1][2] == brush_box(under[0])[1][2] + 32 , str(
        raised
    );
    source = repo / "touch_plot.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "touch_plot.png");
    source.unlink();
    print(
        f"TOUCH PASS: {len(steps) - 1} steps, a terrace's corners moved together, a plot of cells outlined, lifted and "
            + "painted, a plot picked by a press, and the terrain's top and bottom moved apart"
    );
}

"""The forty-second session: faces linked and pushed together, a carve
that keeps divided faces linked, a mitred seam and a merged corner."""
def links_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["miter", "merged"];
    for shot in shots {
        (repo / f"links_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-links-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/links_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "links.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The links session failed: {output / 'links.log'}";
        saved = (Path(home) / "scenes/joined.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["both", "linked", "pushed", "unpushed", "cleared", "carved", "walls", "mitred", "merged"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'links.log'}";
    }
    count = links_counted(steps["linked"]);
    # Two boxes side by side share four planes: linked, the top of one pushed lifts the other's.
    assert "linked 4 total=4" in steps["both"] and count == 4 , str(steps["both"]);
    lifted = brushes(steps["pushed"]);
    assert len(lifted) == 1 and brush_box(lifted[0])[1][2] == 96 and brush_box(lifted[0])[0][0] == 40 , str(lifted);
    back = brushes(steps["unpushed"]);
    assert len(back) == 1 and brush_box(back[0])[1][2] == 64 , str(back);
    assert "linked 4 total=0" in steps["unpushed"] and links_counted(steps["cleared"]) == 0 , str(steps["unpushed"]);
    # Carved in two with links: the two pieces keep their four divided faces as one, and the map says so.
    assert "carved pieces=2 linked=4 total=4" in steps["cleared"] , str(steps["cleared"]);
    assert links_counted(steps["carved"]) == 4 and '"_links" "' in saved , str(steps["carved"]);
    # Two walls through one corner: each gains the seam as a seventh side, as one step.
    before = brushes(steps["walls"]);
    after = brushes(steps["mitred"]);
    assert len(before) == 2 and len(after) == 2 and " sides=6 " in before[0] and " sides=6 " in before[1] , str(before);
    assert " sides=7 " in after[0] and " sides=7 " in after[1] , str(after);
    assert brush_box(after[0]) == brush_box(before[0]) and brush_box(after[1]) == brush_box(before[1]);
    # A top corner moved onto the one beneath: the box keeps its extent and its top is two faces.
    merged = brushes(steps["merged"]);
    assert len(merged) == 1 and " sides=7 " in merged[0] and brush_box(merged[0]) == [[40, 112, 0], [232, 208, 64]] , str(merged);
    for shot in shots {
        source = repo / f"links_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"links_{shot}.png");
        source.unlink();
    }
    print(
        f"LINKS PASS: {len(steps) - 1} steps, two boxes' shared planes linked and pushed together, a carve keeping "
            + "divided faces linked, two walls mitred and a corner merged"
    );
}

"""How many links a step's dump counts (none when it has no line for them)."""
def links_counted(lines: list[str]) -> int {
    found = [line for line in lines if line.startswith("links=")];
    return int(found[0][6:]) if found else 0;
}

"""The forty-first session: a material, a class and a prefab dragged from
the side panels and dropped in the view."""
def drop_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["materials", "classes", "library"];
    for shot in shots {
        (repo / f"drop_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-drop-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PREFABS"] = home + "/prefabs";
        env["QP_TEXTURES"] = home + "/textures";
        (Path(home) / "textures").mkdir();
        (Path(home) / "textures/crate.png").write_bytes(checker_png(4));
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/drop_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_TEXTURES");
        env.pop("QP_PREFABS");
        (output / "drop.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The drop session failed: {output / 'drop.log'}";
        saved = (Path(home) / "scenes/drops.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "painted", "lit", "stacked"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'drop.log'}";
    }
    # The image dragged from the Materials tab lies on one face of the box, and on no other.
    onto = [line for line in steps["made"] if line.startswith("dropped material file:crate.png on #")];
    assert len(onto) == 1 , str(steps["made"]);
    assert len([line for line in saved.splitlines() if " file:crate.png [" in line]) == 1 , saved[:800];
    # A light dragged from the Classes tab stands where it was dropped: on the floor, off to one side.
    lamp = [line for line in steps["painted"] if line.startswith("dropped class light at ")];
    assert len(lamp) == 1 , str(steps["painted"]);
    place = [int(part) for part in lamp[0].split(" at ")[1].split(",")];
    assert place[0] < -64 and place[1] < 0 and 0 < place[2] and place[2] <= 32 , str(place);
    chosen = selected(steps["lit"]);
    assert len(chosen) == 1 and "classname=light" in chosen[0] and f"origin={place[0]} {place[1]} {place[2]}" in chosen[0] , str(
        chosen
    );
    # The prefab dragged from the Library tab stands on top of the box, not where the camera looked.
    crate = [line for line in steps["lit"] if line.startswith("dropped prefab crate at ")];
    assert len(crate) == 1 and crate[0].endswith(",64") , str(steps["lit"]);
    group = selected(steps["stacked"]);
    assert len(group) == 1 and "_group_name=crate" in group[0] and [line for line in steps["stacked"] if line.startswith("brushes=3 ")];
    for shot in shots {
        source = repo / f"drop_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"drop_{shot}.png");
        source.unlink();
    }
    print(
        f"DROP PASS: {len(steps) - 1} steps, a material dragged onto a face, a light onto the floor at {place[0]} {place[1]} "
            + f"{place[2]}, and a prefab onto the top of a box"
    );
}

"""The fortieth session: a model's triangles and points picked by clicks,
a point dragged, tags, a frame moved in the order, and skins."""
def rig_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["faces", "tags"];
    for shot in shots {
        (repo / f"rig_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-rig-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_MODELS"] = home + "/models";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/rig_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_MODELS");
        (output / "rig.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The rig session failed: {output / 'rig.log'}";
        md3 = (Path(home) / "models/rig.md3").read_bytes();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "made", "faceclick", "added", "pointclick", "dragged", "undragged", "tagged", "first", "moved", "skinned"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'rig.log'}";
    }
    # A click on the top: one triangle of its eight, with its three points; Shift adds another.
    clicked = [line for line in steps["made"] if line.startswith("clicked faces ")];
    assert clicked and 16 <= int(clicked[0].split()[2]) and int(clicked[0].split()[2]) <= 23 , str(steps["made"]);
    assert model_word(steps["faceclick"], "picked") == "3/1" , str(steps["faceclick"]);
    assert model_word(steps["added"], "picked").endswith("/2") , str(steps["added"]);
    # A click on the middle of the top picks that one point; dragged with Ctrl it is moved, as one step.
    assert model_word(steps["pointclick"], "picked") == "1/0" and model_word(steps["pointclick"], "pick") == "points" , str(
        steps["pointclick"]
    );
    hub = [line for line in steps["added"] if line.startswith("clicked points ")];
    # One of the two points on the cylinder's axis: the view looks straight down it.
    assert hub and hub[0] in ["clicked points 16", "clicked points 17"] , str(steps["added"]);
    assert model_word(steps["dragged"], "undo") == "1" and model_word(steps["undragged"], "undo") == "0";
    before = int(model_word(steps["pointclick"], "volume"));
    assert int(model_word(steps["dragged"], "volume")) != before and int(model_word(steps["undragged"], "volume")) == before;
    # Tags: two, one moved at the copied frame only.
    assert model_word(steps["tagged"], "tags") == "2" and model_word(steps["tagged"], "frames") == "2";
    raised = [line for line in steps["tagged"] if line.startswith("tag ")];
    assert raised == ["tag tag_top at=0,0,128 frames=2", "tag tag_side at=32,0,48 frames=2"] , str(raised);
    stood = [line for line in steps["first"] if line.startswith("tag ")];
    assert stood == ["tag tag_top at=0,0,96 frames=2", "tag tag_side at=32,0,48 frames=2"] , str(stood);
    # The copied frame at the front of the order; one tag and one skin left.
    assert model_word(steps["moved"], "frame") == "0:up" , str(steps["moved"]);
    assert model_word(steps["skinned"], "tags") == "1" and model_word(steps["skinned"], "skins") == "1";
    assert [line for line in steps["skinned"] if line == "skin 0 models/tower/alt.tga"] , str(steps["skinned"]);
    assert md3[:4] == b"IDP3" and int.from_bytes(md3[76:80], "little") == 2 and int.from_bytes(md3[80:84], "little") == 1;
    assert b"models/tower/alt.tga" in md3 and b"tag_top" in md3 and b"tag_side" not in md3;
    for shot in shots {
        source = repo / f"rig_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"rig_{shot}.png");
        source.unlink();
    }
    print(
        f"RIG PASS: {len(steps) - 1} steps, triangles and a point picked by clicks in the model's view, the point dragged "
            + "and that undone, two tags moved by frame, a frame moved to the front, and a part's skins"
    );
}

"""The thirty-eighth session: a played game's firings counted, a firing
that holds the game, and the live player and signals changed while held."""
def live_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "live_graph.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-live-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/live_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "live.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The live session failed: {output / 'live.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "quiet", "broke", "after", "changed", "again", "stopped", "graph"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'live.log'}";
    }
    assert [line for line in steps["made"] if line == "breaks first"] or "studio: breaks first" in ran.stdout;
    # Nothing has fired until the first relay is set off; then all three have, and the game is held.
    assert "signals none" in steps["quiet"] , str(steps["quiet"]);
    assert [line for line in steps["quiet"] if line == "break first"] , str(steps["quiet"]);
    assert played_word(steps["broke"], "held") == "1" , str(steps["broke"]);
    assert "signals door1=1 first=1 start=1" in steps["after"] , str(steps["after"]);
    order = [line for line in steps["after"] if line.startswith("order ")][0][6:].split(",");
    assert sorted(order) == ["door1", "first", "start"] , str(order);
    # The live game as it stood, and as changed: the player's health and place, a relay switched off.
    stood = [line for line in steps["after"] if line.startswith("live player ")];
    assert stood and "health=100" in stood[0] and "held=1" in stood[0] , str(steps["after"]);
    was = [line for line in steps["after"] if line.startswith("live signal first ")];
    assert was and was[0] == "live signal first class=trigger_relay enabled=1 fired=1" , str(steps["after"]);
    now = [line for line in steps["changed"] if line.startswith("live player ")];
    assert now and now[0] == "live player at=0,-200,40 health=37 held=1" , str(steps["changed"]);
    off_now = [line for line in steps["changed"] if line.startswith("live signal first ")];
    assert off_now and off_now[0] == "live signal first class=trigger_relay enabled=0 fired=1" , str(steps["changed"]);
    # Fired again, the firing stops at the relay that is off; the counts outlast the game.
    assert "signals door1=1 first=1 start=2" in steps["again"] , str(steps["again"]);
    assert "signals door1=1 first=1 start=2" in steps["stopped"] , str(steps["stopped"]);
    assert "breaks first" in steps["stopped"] , str(steps["stopped"]);
    source = repo / "live_graph.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "live_graph.png");
    source.unlink();
    print(
        f"LIVE PASS: {len(steps) - 1} steps, three signals counted as they fired, the game held when one of them did, "
            + "the player's health and place and a relay changed while it was held, and the firing stopped there after"
    );
}

"""The thirty-seventh session: outlines swept along a line and a path, a
sweep swept again after its path moved, and a brush's own outline swept."""
def sweep_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["rail", "ring"];
    for shot in shots {
        (repo / f"sweep_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-sweep-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/sweep_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "sweep.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The sweep session failed: {output / 'sweep.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["beam", "rail", "again", "piece", "undone", "ring"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'sweep.log'}";
    }
    # A square along a line with one turn: a group of two brushes that keeps what it was swept from.
    beam = selected(steps["beam"]);
    assert len(beam) == 1 and "_group_name=sweep" in beam[0] and "_sweep=square 32.0 16.0 8" in beam[0]
        and beam[0].endswith("owns=2") , str(beam);
    # A rail, three pieces, along two stretches of a path of named corners.
    rail = selected(steps["rail"]);
    assert len(rail) == 1 and "_along=c1" in rail[0] and "_sweep=rail 24.0 48.0 8" in rail[0] and rail[0].endswith("owns=6") , str(
        rail
    );
    assert [line for line in steps["rail"] if line == "swept again brushes=6"] , str(steps["rail"]);
    # Its last corner moved out and up: swept again, its last piece reaches there; undone, it is back.
    moved = brushes(steps["piece"]);
    assert len(moved) == 1 and brush_box(moved[0])[1][0] >= 120 and brush_box(moved[0])[1][2] >= 100 , str(moved);
    back = brushes(steps["undone"]);
    assert len(back) == 1 and brush_box(back[0])[1][0] <= 16 and brush_box(back[0])[1][2] <= 76 , str(back);
    # A drawn brush's outline round a closed line: four brushes, mitred at every corner.
    ring = selected(steps["ring"]);
    assert len(ring) == 1 and "_sweep=brush " in ring[0] and "_closed=1" in ring[0] and "_outline=" in ring[0]
        and ring[0].endswith("owns=4") , str(ring);
    assert [line for line in steps["ring"] if line.startswith("brushes=14 ")] , str(steps["ring"]);
    for shot in shots {
        source = repo / f"sweep_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"sweep_{shot}.png");
        source.unlink();
    }
    print(
        f"SWEEP PASS: {len(steps) - 1} steps, a beam along a line, a rail along a path of corners and again after one "
            + "moved, and a brush's own outline round a closed line"
    );
}

"""A step's line of the layers that are off, if it has one."""
def off(lines: list[str]) -> list[str] {
    return [line for line in lines if line.startswith("layers off=")];
}

"""The thirty-sixth session: kept sets hidden and shown as layers."""
def layers_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["hidden", "list"];
    for shot in shots {
        (repo / f"layers_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-layers-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/layers_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "layers.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The layers session failed: {output / 'layers.log'}";
        saved = (Path(home) / "scenes/tiers.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["kept", "hid", "through", "both", "back", "only", "shown"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'layers.log'}";
    }
    assert [line for line in steps["kept"] if line == "sets=west:1,east:1,boxes:2"] , str(steps["kept"]);
    assert not off(steps["kept"]) and hidden(steps["kept"]) == 0 and made(steps["kept"]) == 3 , str(steps["kept"]);
    # One layer off: its box is hidden and is not in what the views are built from.
    assert off(steps["hid"]) == ["layers off=west"] and hidden(steps["hid"]) == 1 and made(steps["hid"]) == 2 , str(
        steps["hid"]
    );
    # A click where it stood finds the floor.
    under = brushes(steps["through"]);
    assert len(under) == 1 and under[0].split()[1] == "#1" , str(steps["through"]);
    # The layer of both off, the first on again: both boxes stay hidden.
    assert off(steps["both"]) == ["layers off=boxes"] and hidden(steps["both"]) == 2 and made(steps["both"]) == 1 , str(
        steps["both"]
    );
    listed = [line for line in steps["both"] if line.startswith("layer ")];
    assert listed == ["layer west shown holds=1", "layer east shown holds=1", "layer boxes hidden holds=2"] , str(listed);
    # Toggled back, everything shows; one alone hides what the others hold, shared or not.
    assert not off(steps["back"]) and hidden(steps["back"]) == 0 and made(steps["back"]) == 3 , str(steps["back"]);
    assert off(steps["only"]) == ["layers off=boxes,west"] and hidden(steps["only"]) == 2 , str(steps["only"]);
    assert '"_layers_off" "boxes west"' in saved and '"_set_east"' in saved , saved[:600];
    # Showing everything turns every layer on.
    assert not off(steps["shown"]) and hidden(steps["shown"]) == 0 and made(steps["shown"]) == 3 , str(steps["shown"]);
    for shot in shots {
        source = repo / f"layers_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"layers_{shot}.png");
        source.unlink();
    }
    print(
        f"LAYERS PASS: {len(steps) - 1} steps, three layers of two boxes hidden, shown and shown alone, what two share "
            + "kept hidden while either is off, and the layers that are off saved with the map"
    );
}

"""The thirty-fifth session: an axis view held to a band of depth, what is
outside it greyed or left out, and axis views turned off their axes."""
def depth_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["grey", "hidden", "oblique"];
    for shot in shots {
        (repo / f"depth_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-depth-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/depth_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "depth.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The depth session failed: {output / 'depth.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "made", "banded", "greyclick", "hideclick", "fitted", "unbanded", "oblique", "turned", "straight", "done"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'depth.log'}";
    }
    # The second box, lifted: 192 to 256 up.
    lifted = brushes(steps["made"]);
    assert len(lifted) == 1 and brush_box(lifted[0])[0][2] == 192 and brush_box(lifted[0])[1][2] == 256 , str(lifted);
    high = lifted[0].split()[1];
    # Held to -32..96, the top view has one brush outside its band; greyed, it is still clicked.
    band = [line for line in steps["banded"] if line.startswith("depth ")];
    assert band == ["depth top=-32..96/1 outside=grey"] , str(steps["banded"]);
    assert len(brushes(steps["greyclick"])) == 1 and brushes(steps["greyclick"])[0].split()[1] == high , str(
        steps["greyclick"]
    );
    # Left out, the click goes to the floor beneath it.
    under = brushes(steps["hideclick"]);
    assert len(under) == 1 and under[0].split()[1] == "#1" and brush_box(under[0])[1][2] == 0 , str(steps["hideclick"]);
    assert [line for line in steps["hideclick"] if line.startswith("depth top=-32..96/1 outside=hide")];
    # From the selection: its own depths and eight more each way, the other two brushes outside.
    assert [line for line in steps["fitted"] if line == "depth top=184..264/2 outside=hide"] , str(steps["fitted"]);
    assert not [line for line in steps["unbanded"] if line.startswith("depth ")];
    assert "ed_outside hide" in kept , kept;
    # Oblique: the top view by command, the front by Alt and a hundred pixels of right drag.
    assert [line for line in steps["oblique"] if line == "oblique top=45,-35"] , str(steps["oblique"]);
    both = [line for line in steps["turned"] if line.startswith("oblique ")];
    assert both and both[0].startswith("oblique top=45,-35 front=") , str(steps["turned"]);
    front = [int(part) for part in both[0].split("front=")[1].split(",")];
    assert 27 <= abs(front[0] - 90) and abs(front[0] - 90) <= 30 and front[1] == 0 , str(front);
    # A press on the compass straightens the top view; a command the front.
    one = [line for line in steps["straight"] if line.startswith("oblique ")];
    assert one and one[0].startswith("oblique front=") , str(steps["straight"]);
    assert not [line for line in steps["done"] if line.startswith("oblique ")];
    for shot in shots {
        source = repo / f"depth_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"depth_{shot}.png");
        source.unlink();
    }
    print(
        f"DEPTH PASS: {len(steps) - 1} steps, the top view held to a band with a box above it greyed, then left out and "
            + "clicked through, the band taken from the selection, and two views turned off their axes and straightened"
    );
}

"""The thirty-fourth session: a file opened with the program kept for its
ending, an image changed outside read again, and the mouse's options."""
def outside_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "outside_changed.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-outside-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_TEXTURES"] = home + "/textures";
        (Path(home) / "textures").mkdir();
        (Path(home) / "spare").mkdir();
        # The image as it begins, four texels a side, and what the stand-in
        # editor turns it into, eight.
        (Path(home) / "textures/crate.png").write_bytes(checker_png(4));
        (Path(home) / "spare/crate.png").write_bytes(checker_png(8));
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/outside_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_TEXTURES");
        (output / "outside.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The outside session failed: {output / 'outside.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        edited = (Path(home) / "textures/crate.png").read_bytes() == checker_png(8);
    }
    steps = studio_steps(ran.stdout);
    names = ["own", "kept", "changed", "level", "turned", "faster", "wheeled", "reversed"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'outside.log'}";
    }
    # The image as it was: four texels across 128 units.
    assert "scale=32.0,24.0" in faces(steps["own"])[0] , str(faces(steps["own"]));
    # One program kept, the other forgotten; the material's file opened with it.
    listed = [line for line in steps["kept"] if line.startswith("assoc ")];
    assert listed == ["assoc png = sh scripts/studio/fixtures/fake_editor.sh %file%"] , str(listed);
    opened = [line for line in steps["kept"] if line.startswith("opened ")];
    assert opened and opened[0].endswith("/textures/crate.png with sh scripts/studio/fixtures/fake_editor.sh %file%") , str(
        steps["kept"]
    );
    # It changed the file; the studio read it again unasked, and it fits at its new size.
    assert edited , "The stand-in editor did not change the image";
    again = [line for line in steps["kept"] if line.startswith("reloaded ")];
    assert again == ["reloaded file:crate.png 8x8"] , str(steps["kept"]);
    assert "scale=16.0,12.0" in faces(steps["changed"])[0] , str(faces(steps["changed"]));
    assert 'ed_assoc png "sh scripts/studio/fixtures/fake_editor.sh %file%"' in kept and "ed_assoc tga" not in kept , kept;
    # The mouse: a hundred pixels across and twenty down turn the camera
    # about 29 degrees and 6; at twice the rate, 57 and 11, and upside down
    # the other way up.
    level_yaw = int(line_word(steps["level"], "mouse ", "yaw"));
    level_pitch = int(line_word(steps["level"], "mouse ", "pitch"));
    assert level_yaw == 90 and level_pitch == 0 , str(steps["level"]);
    yaw = int(line_word(steps["turned"], "mouse ", "yaw")) - level_yaw;
    pitch = int(line_word(steps["turned"], "mouse ", "pitch")) - level_pitch;
    assert 27 <= abs(yaw) and abs(yaw) <= 30 and 5 <= abs(pitch) and abs(pitch) <= 7 , f"{yaw} {pitch}";
    fast_yaw = int(line_word(steps["faster"], "mouse ", "yaw")) - level_yaw;
    fast_pitch = int(line_word(steps["faster"], "mouse ", "pitch")) - level_pitch;
    assert 56 <= abs(fast_yaw) and abs(fast_yaw) <= 59 and fast_yaw * yaw > 0 , f"{fast_yaw} against {yaw}";
    assert 10 <= abs(fast_pitch) and abs(fast_pitch) <= 13 and fast_pitch * pitch < 0 , f"{fast_pitch} against {pitch}";
    assert line_word(steps["faster"], "mouse ", "look") == "2.0" and line_word(steps["faster"], "mouse ", "invert") == "1";
    # The wheel: sixty-four units forward a notch; twice as far and backward when told.
    assert camera_at(steps["wheeled"]) == [0, -356, 260] , str(camera_at(steps["wheeled"]));
    assert camera_at(steps["reversed"]) == [0, -548, 260] , str(camera_at(steps["reversed"]));
    assert "ed_mouse look 2.0" in kept and "ed_mouse invert on" in kept and "ed_mouse wheel 2.0" in kept
        and "ed_mouse reverse on" in kept , kept;
    source = repo / "outside_changed.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "outside_changed.png");
    source.unlink();
    print(
        f"OUTSIDE PASS: {len(steps) - 1} steps, an image opened with the program kept for it and read again when that "
            + f"changed it, the camera turned {abs(yaw)} then {abs(fast_yaw)} degrees by the same drag, and the wheel reversed"
    );
}

"""The thirty-third session: a project made and filled, another opened,
add-ons of classes loaded and dropped, and what a game's scenes begin with."""
def project_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["addon", "menu"];
    for shot in shots {
        (repo / f"project_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-project-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_PROJECTS"] = home + "/projects";
        # A project from before: a manifest, a scene and an add-on of its own.
        old = Path(home) / "projects/old";
        (old / "scenes").mkdir(parents=True);
        (old / "classes").mkdir();
        shutil.copyfile(repo / "scripts/studio/fixtures/hall.map", old / "scenes/hall.map");
        shutil.copyfile(repo / "scripts/studio/fixtures/traps.txt", old / "classes/traps.txt");
        before = "// A QuakePassion project.\nname \"The old hall\"\ngame q1\nstart hall\nscene hall\naddon classes/traps.txt\n";
        (old / "project.qp").write_text(before);
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/project_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "project.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The project session failed: {output / 'project.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        manifest = (Path(home) / "projects/keep/project.qp").read_text();
        after = (old / "project.qp").read_text();
        saved = sorted([each.name for each in (Path(home) / "projects/keep/scenes").glob("*.map")]);
        loose = (Path(home) / "scenes/loose.map").read_text();
        yard = (Path(home) / "projects/keep/scenes/yard.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["begin", "kept", "addon", "spikes", "dropped", "menu", "closed", "old", "games", "loose"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'project.log'}";
    }
    # The project made: its manifest says what was set, a line a fact, in a fixed order.
    assert not [line for line in steps["begin"] if line.startswith("project ")];
    assert manifest == (
        "// A QuakePassion project.\nname \"The keep\"\ngame passion\nstart yard\nmaterial brick\nbuild quick\nbake 128\n"
            + "scene hall\nscene yard\nrecipe fine \"ed_build full; ed_bake 128\"\n"
    ) , manifest;
    assert saved == ["hall.map", "yard.map"] , str(saved);
    told = [line for line in steps["kept"] if line.startswith("project ")];
    assert told and told[0].startswith("project keep game=passion start=yard scenes=hall,yard material=brick build=quick bake=128")
        and told[0].endswith("recipes=1 name=The keep") , str(told);
    # The level in hand is built as the project says: cut into cells.
    assert bake_word(steps["kept"], "cells") >= 4 , str(steps["kept"]);
    # An add-on's classes: listed, an entity of one made, read again, dropped.
    listed = [line for line in steps["addon"] if line.startswith("addon ")];
    assert listed and listed[0] == "addon scripts/studio/fixtures/traps.txt classes=trap_spikes,trap_pit" , str(steps["addon"]);
    tools = [line for line in steps["addon"] if line.startswith("tools ")];
    assert tools and " addons=1 " in tools[0] and " recipes=1 " in tools[0] , str(tools);
    assert len(selected(steps["spikes"])) == 1 and "classname=trap_spikes" in selected(steps["spikes"])[0] , str(
        steps["spikes"]
    );
    assert [line for line in steps["spikes"] if line.startswith("reloaded scripts/studio/fixtures/traps.txt classes=2")];
    gone = [line for line in steps["dropped"] if line.startswith("tools ")];
    assert gone and " addons=0 " in gone[0] and not [line for line in steps["dropped"] if line.startswith("addon ")];
    assert int(tools[0].split("classes=")[1].split()[0]) == int(gone[0].split("classes=")[1].split()[0]) + 2;
    # Asked from the Window menu, the project says what it is: once in the
    # step's own dump, once for the click.
    assert len([line for line in steps["menu"] if line.startswith("project keep ")]) == 2 , str(steps["menu"]);
    # Closed, and the older one opened: its scene shown, its add-on loaded, its manifest as it was.
    assert not [line for line in steps["closed"] if line.startswith("project ")];
    opened = [line for line in steps["old"] if line.startswith("project ")];
    assert opened and opened[0].startswith("project old game=q1 start=hall scenes=hall ")
        and opened[0].endswith("addons=1 recipes=0 name=The old hall") , str(opened);
    assert len(brushes(steps["old"])) == 0 and tally(steps["old"]) , str(steps["old"]);
    assert [line for line in steps["old"] if line.startswith("brushes=7 ")] , str(steps["old"]);
    theirs = [line for line in steps["old"] if line.startswith("addon ")];
    assert theirs and theirs[0].endswith("/projects/old/classes/traps.txt classes=trap_spikes,trap_pit") , str(steps["old"]);
    assert after == before , after;
    # A game's setup: kept in the settings, and the next scene made outside
    # a project is floored with its material.
    said = [line for line in steps["games"] if line.startswith("game passion ")];
    assert said and said[0].startswith("game passion material=slate build=flat bake=- dir=") , str(steps["games"]);
    assert 'ed_game passion material "slate"' in kept and 'ed_game passion build "flat"' in kept , kept;
    assert "ed_addon" not in kept and "ed_recipe" not in kept , kept;
    assert "slate" in loose and "brick" not in loose and "slate" not in yard , loose;
    for shot in shots {
        source = repo / f"project_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"project_{shot}.png");
        source.unlink();
    }
    print(
        f"PROJECT PASS: {len(steps) - 1} steps, a project made with two scenes and a recipe in its manifest, an add-on's "
            + "classes loaded, used and dropped, an older project opened with its own, and a game's scenes floored as set"
    );
}

"""The thirtieth session: an entity's facing and a light's reach dragged by
their handles, a path drawn, logic added from the library, a favourite."""
def marks_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["faced", "light", "path"];
    for shot in shots {
        (repo / f"marks_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-marks-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/marks_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "marks.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The marks session failed: {output / 'marks.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["start", "faced", "lamp", "brighter", "clicked", "counter", "favourite"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'marks.log'}";
    }
    # The arrow's tip swung a quarter round: from facing +y to facing +x.
    assert "angle=90" in selected(steps["start"])[0] and "angle=0" in selected(steps["faced"])[0] , (
        f"{selected(steps['start'])} {selected(steps['faced'])}"
    );
    # The light's reach pulled out from 200 units to 400: its value from 100 to 200.
    lamp = selected(steps["lamp"])[0];
    brighter = selected(steps["brighter"])[0];
    assert "classname=light" in lamp and "light=100" in lamp and "light=200" in brighter , f"{lamp} {brighter}";
    # A handle clicked and not dragged leaves it be.
    assert steps["clicked"][0] == steps["brighter"][0] and "light=200" in selected(steps["clicked"])[0];
    # The game's pieces of logic are listed, and a counter is one of its classes, named so it shows in the graph.
    kinds = [line.split()[-1] for line in ran.stdout.splitlines() if line.startswith("studio: logic kind ")];
    assert "relay" in kinds and "counter" in kinds and "delay" in kinds , str(kinds);
    counter = selected(steps["counter"])[0];
    assert "classname=trigger_counter" in counter and "targetname=counter1" in counter and "count=2" in counter , counter;
    # The favourite is kept in the settings and adds one of its class.
    favourite = selected(steps["favourite"])[0];
    assert "classname=item_health" in favourite and "ed_fav item_health" in kept , f"{favourite} {kept}";
    for shot in shots {
        source = repo / f"marks_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"marks_{shot}.png");
        source.unlink();
    }
    print(
        f"MARKS PASS: {len(steps) - 1} steps, an entity turned by its arrow and a light's reach pulled out, a "
            + "path drawn, logic from the library and a favourite class"
    );
}

"""The twenty-ninth session: keys bound by hand, the settings list, the
grid hidden, flat tones, and the developer's readout, kept between runs."""
def settings_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["list", "nogrid", "solid", "dev"];
    for shot in shots {
        (repo / f"settings_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-settings-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/settings_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "settings.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The settings session failed: {output / 'settings.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        again = subprocess.run(
            [str(binary), "+edit", "+wait", "+wait", "+ed_binds", "+ed_dump", "again", "+quit"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "settings_again.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Opening the studio again failed: {output / 'settings_again.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["column", "cap", "unbound", "solid", "textured"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'settings.log'}";
    }
    # K made a column (a group of three brushes); Shift+K a cap (eight); unbound, Shift+K makes nothing.
    column = selected(steps["column"]);
    cap = selected(steps["cap"]);
    assert len(column) == 1 and "_group_name=column" in column[0] and "owns=3" in column[0] , str(column);
    assert len(cap) == 1 and "_group_name=cap" in cap[0] and "owns=8" in cap[0] , str(cap);
    assert tally(steps["unbound"]).split()[0] == tally(steps["cap"]).split()[0] , f"{tally(steps['cap'])} {tally(steps['unbound'])}";
    assert "studio: key k ed_shape column 64 64 128" in ran.stdout and "studio: key shift+k ed_shape cap 128 32 64" in ran.stdout;
    # The settings list says what is so; its second line hid the grid.
    said = [line[len("studio: setting "):] for line in ran.stdout.splitlines() if line.startswith("studio: setting ")];
    assert len(said) == 24 and said[1] == "Grid shown" and said[13] == "Grid hidden" , str(said[:14]);
    assert said[0] == "Grid 16 (coarser)" and "Materials as textures" in said;
    # Flat tones build the level again from other materials, and textures bring it back.
    solid = tally(steps["solid"]);
    assert solid.split("geometry=")[1].split()[0] == solid.split("built=")[1].split()[0] , solid;
    # Kept: the key, the grid shown again, the readout on.
    assert 'ed_bind k "ed_shape column 64 64 128"' in kept and "ed_bind shift+k" not in kept , kept;
    assert "ed_grid show" in kept and "ed_dev on" in kept , kept;
    assert "studio: key k ed_shape column 64 64 128" in again.stdout;
    for shot in shots {
        source = repo / f"settings_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"settings_{shot}.png");
        source.unlink();
    }
    print(
        f"SETTINGS PASS: {len(steps) - 1} steps, keys bound by hand and kept, the settings list, the grid hidden, "
            + "materials as flat tones, and the developer's readout"
    );
}

"""A word of a face line (`material`, `shift`, `scale`)."""
def face_word(line: str, key: str) -> str {
    return line.split(key + "=")[1].split()[0];
}

"""The twenty-eighth session: a material wrapped round a corner from a
tagged face, projected, fitted in whole repeats and painted by a drag; and
a face put in the tagged plane."""
def wrap_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "wrap_painted.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-wrap-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/wrap_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "wrap.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The wrap session failed: {output / 'wrap.log'}";
        text = (Path(home) / "scenes/wrap.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["tagged", "wrapped", "projected", "fitted", "painted", "glued"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'wrap.log'}";
    }
    tagged = faces(steps["tagged"]);
    assert len(tagged) == 1 and face_word(tagged[0], "material") == "tile" and face_word(tagged[0], "shift") == "8.0,4.0" , str(tagged);
    # The next face has the tagged one's material, carried round: another face, laid another way.
    wrapped = faces(steps["wrapped"]);
    assert len(wrapped) == 1 and wrapped[0].split()[1] != tagged[0].split()[1] , f"{tagged} {wrapped}";
    assert face_word(wrapped[0], "material") == "tile" and face_word(wrapped[0], "scale") == "1.0,1.0" , wrapped[0];
    # The one after has it exactly as the tagged face does.
    projected = faces(steps["projected"]);
    assert face_word(projected[0], "material") == "tile" and face_word(projected[0], "shift") == "8.0,4.0" , projected[0];
    assert projected[0].split()[1] not in [tagged[0].split()[1], wrapped[0].split()[1]];
    # Fitted in whole repeats: a texel is still near a unit each way.
    scales = [abs(float(part)) for part in face_word(faces(steps["fitted"])[0], "scale").split(",")];
    assert 0.6 < scales[0] < 1.5 and 0.6 < scales[1] < 1.5 , str(scales);
    # The drag painted two faces: the box's top and the floor's.
    assert text.count(" moss ") == 2 , str(text.count(" moss "));
    edits = int(steps["painted"][0].split("undo=")[1].split()[0]) - int(steps["fitted"][0].split("undo=")[1].split()[0]);
    assert edits == 2 , str(edits);
    # The floor's top in the tagged plane: the floor reaches up to the box's top.
    floor = brush_box(brushes(steps["glued"])[0]);
    assert floor[0][2] == -16 and floor[1][2] == 64 , str(floor);
    source = repo / "wrap_painted.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "wrap_painted.png");
    source.unlink();
    print(
        f"WRAP PASS: {len(steps) - 1} steps, a material wrapped round a corner, projected, fitted in whole "
            + "repeats and painted by a drag, and a face put in the tagged plane"
    );
}

"""The twenty-seventh session: a slider, colour bars, a field of three
numbers and a radio, each dragged or clicked in the inspector."""
def controls_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["light", "brush"];
    for shot in shots {
        (repo / f"controls_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-controls-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/controls_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "controls.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The controls session failed: {output / 'controls.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["start", "bright", "tinted", "moved", "turn", "size", "box"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'controls.log'}";
    }
    start = selected(steps["start"])[0];
    assert "classname=light" in start and "origin=0 -273 179" in start and "light=" not in start , start;
    # The knob let go halfway along a bar that runs to a thousand.
    assert "light=500" in selected(steps["bright"])[0] , str(selected(steps["bright"]));
    # Half the green: one edit, as one word.
    tinted = selected(steps["tinted"])[0];
    assert "_color=1 0.5 1" in tinted and "light=500" in tinted , tinted;
    # Five grid steps of eight, up.
    assert "origin=0 -273 219" in selected(steps["moved"])[0] , str(selected(steps["moved"]));
    edits = int(steps["moved"][0].split("undo=")[1].split()[0]) - int(steps["start"][0].split("undo=")[1].split()[0]);
    assert edits == 3 , str(edits);
    assert "handles=turn" in handles(steps["turn"]) and "handles=size" in handles(steps["size"]);
    assert "handles=box" in handles(steps["box"]) , handles(steps["box"]);
    for shot in shots {
        source = repo / f"controls_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"controls_{shot}.png");
        source.unlink();
    }
    print(
        f"CONTROLS PASS: {len(steps) - 1} steps, a light's strength by a slider and colour by bars, its place by "
            + "a field of three numbers, and a brush's handles by a radio"
    );
}

"""How many prisms a step's patch line counts, and its grid as "WxH"."""
def patch_shape(lines: list[str]) -> list[str] {
    found = patches(lines);
    return [found[-1].split()[2], found[-1].split("prisms=")[1].split()[0]] if found else ["", "0"];
}

"""The twenty-sixth session: a curved sheet grown across and up, shrunk,
thickened and made finer; and an endcap."""
def quilt_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["grown", "endcap"];
    for shot in shots {
        (repo / f"quilt_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-quilt-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/quilt_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "quilt.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The quilt session failed: {output / 'quilt.log'}";
        text = (Path(home) / "scenes/quilt.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "wider", "taller", "narrower", "fine", "endcap"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'quilt.log'}";
    }
    made = patch_shape(steps["made"]);
    wider = patch_shape(steps["wider"]);
    taller = patch_shape(steps["taller"]);
    narrower = patch_shape(steps["narrower"]);
    fine = patch_shape(steps["fine"]);
    assert made[0] == "3x3" and wider[0] == "5x3" and taller[0] == "5x5" and narrower[0] == "3x5" , (
        f"{made} {wider} {taller} {narrower}"
    );
    # Each curve more doubles the prisms that way; one fewer halves them.
    assert int(wider[1]) == 2 * int(made[1]) and int(taller[1]) == 4 * int(made[1]) and int(narrower[1]) == 2 * int(made[1]);
    # Thicker and finer: its fields say so, and it is made of more prisms.
    assert "_patch=3 5 8 24" in selected(steps["fine"])[0] and int(fine[1]) > int(narrower[1]) , str(steps["fine"]);
    assert patch_shape(steps["endcap"])[0] == "5x3" and len(patches(steps["endcap"])) == 2;
    assert '"_patch" "3 5 8 24"' in text and text.count('"_patch"') == 2;
    for shot in shots {
        source = repo / f"quilt_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"quilt_{shot}.png");
        source.unlink();
    }
    print(
        f"QUILT PASS: {len(steps) - 1} steps, a curved sheet grown across and up, shrunk, thickened and made "
            + "finer, and an endcap"
    );
}

"""The twenty-fifth session: a terrain lifted in a rectangle, split another
way, worn down, painted, and left as plain brushes."""
def land_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "land_worn.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-land-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/land_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "land.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The land session failed: {output / 'land.log'}";
        text = (Path(home) / "scenes/land.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["made", "lifted", "split", "peak", "worn", "painted", "freed"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'land.log'}";
    }
    assert terrain(steps["made"]) == [0, 0] and "owns=32" in selected(steps["made"])[0];
    # Lifted whole: each of its twenty-five corners is thirty-two up.
    assert terrain(steps["lifted"]) == [32, 25] , str(terrain(steps["lifted"]));
    # Split along alternate diagonals: as many brushes, as high, and the group says how.
    split = selected(steps["split"])[0];
    assert "_pattern=alt" in split and "owns=32" in split and terrain(steps["split"]) == [32, 25] , split;
    # A peak, then worn: the tallest corner comes down, and nothing goes up.
    peak = terrain(steps["peak"])[0];
    worn = terrain(steps["worn"])[0];
    assert peak > 100 and 32 <= worn < peak , f"{peak} {worn}";
    # Painted: every prism's top has the material in hand.
    assert text.count(" moss ") == 32 , str(text.count(" moss "));
    # Freed: a group of thirty-two plain brushes, with no grid to sculpt.
    freed = selected(steps["freed"])[0];
    assert "_terrain" not in freed and "_heights" not in freed and "owns=32" in freed , freed;
    assert terrain(steps["freed"]) == [-1, -1] and steps["freed"][0] == steps["painted"][0].replace("undo=6", "undo=7");
    source = repo / "land_worn.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "land_worn.png");
    source.unlink();
    print(
        f"LAND PASS: {len(steps) - 1} steps, a terrain lifted in a rectangle, split another way, worn down, "
            + "painted and left as plain brushes"
    );
}

"""The twenty-fourth session: stairs with a landing built again from other
numbers, caulked and freed; one of each new kind of shape; and shapes made
with their inner faces caulked."""
def shapes_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["landing", "kinds"];
    for shot in shots {
        (repo / f"shapes_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-shapes-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/shapes_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "shapes.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The shapes session failed: {output / 'shapes.log'}";
        text = (Path(home) / "scenes/shapes.map").read_text();
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["landing", "rebuilt", "undone", "caulked", "freed", "kinds", "auto"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'shapes.log'}";
    }
    # Four steps, a landing and four more, as a group that keeps its numbers.
    landing = selected(steps["landing"]);
    assert len(landing) == 1 and "_shape=landing 128 192 128 8 16" in landing[0] and "owns=9" in landing[0] , str(landing);
    # Built again from other numbers: twelve steps and the landing; undone, the nine again.
    rebuilt = selected(steps["rebuilt"])[0];
    assert "_shape=landing 128 192 192 12 16" in rebuilt and "owns=13" in rebuilt , rebuilt;
    assert "owns=9" in selected(steps["undone"])[0] and "_shape=landing 128 192 128 8 16" in selected(steps["undone"])[0];
    # Caulked: some of its brushes now begin with a face that is not drawn, and the map says so.
    assert len(brushes(steps["caulked"])) == 13 , str(len(brushes(steps["caulked"])));
    assert text.count(" caulk ") >= 10 , str(text.count(" caulk "));
    # Freed, it keeps no numbers, and cannot be built again.
    freed = selected(steps["freed"])[0];
    assert "_shape" not in freed and "owns=13" in freed , freed;
    # Seven more shapes: the floor, the landing's thirteen, and theirs.
    count = int(tally(steps["kinds"]).split()[0].split("=")[1]);
    assert count == 1 + 13 + 1 + 12 + 3 + 8 + 6 + 1 + 3 , str(count);
    # With the setting on, new stairs come caulked where a step backs onto the next.
    auto = brushes(steps["auto"]);
    assert len(auto) == 4 and "ed_autocaulk on" in kept , str(auto);
    assert text.count(" caulk ") >= 13 , str(text.count(" caulk "));
    for shot in shots {
        source = repo / f"shapes_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"shapes_{shot}.png");
        source.unlink();
    }
    print(
        f"SHAPES PASS: {len(steps) - 1} steps, stairs with a landing built again, caulked and freed, seven more "
            + "kinds of shape, and shapes that come caulked"
    );
}

"""The twenty-third session: copies that grow, mirror on two axes, hide and
show; images at named points and along a path, made real; and a door whose
images are doors of their own."""
def dups_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["mirrored", "path"];
    for shot in shots {
        (repo / f"dups_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-dups-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/dups_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "dups.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The dups session failed: {output / 'dups.log'}";
        text = (Path(home) / "scenes/dups.map").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "row", "mirrored", "hidden", "shown", "stopped", "torches", "pathed", "real", "doors", "three", "second"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'dups.log'}";
    }
    # The floor, the post and its three copies.
    row = selected(steps["row"]);
    assert len(row) == 1 and "_copies=3" in row[0] and "_offset=32 0 0" in row[0] and made(steps["row"]) == 5 , str(row);
    # Mirrored on x and y: the four of them four times over, and the floor.
    mirrored = selected(steps["mirrored"])[0];
    assert "_grow=1.5" in mirrored and "_axis=x" in mirrored and "_mirror=xy" in mirrored , mirrored;
    assert "_materials=brick stone" in mirrored and made(steps["mirrored"]) == 17 , str(steps["mirrored"]);
    # Hidden, only the document's two brushes are built; shown, all again; stopped, two for good.
    assert made(steps["hidden"]) == 2 and made(steps["shown"]) == 17 and made(steps["stopped"]) == 2;
    assert "_copies" not in selected(steps["stopped"])[0] and "_mirror" not in selected(steps["stopped"])[0];
    # An image at each of two torches; then at each of three path corners instead.
    assert "_at=torch" in selected(steps["torches"])[0] and made(steps["torches"]) == 4 , str(steps["torches"]);
    pathed = selected(steps["pathed"])[0];
    assert "_path=p1" in pathed and "_at" not in pathed and made(steps["pathed"]) == 5 , str(steps["pathed"]);
    # Made real: the group owns four brushes and asks for no more.
    real = selected(steps["real"])[0];
    assert "owns=4" in real and "_path" not in real and made(steps["real"]) == 5 , real;
    # One door in the document; three in the game, of which the second is fired by its counted name.
    door = selected(steps["doors"])[0];
    assert "classname=func_door" in door and "_each=1" in door and "owns=1" in door , door;
    assert played_word(steps["three"], "doors") == "closed,closed,closed" , str(steps["three"]);
    after = played_word(steps["second"], "doors").split(",");
    assert len(after) == 3 and after[0] == "closed" and after[1] != "closed" and after[2] == "closed" , str(after);
    assert "studio: fired door2 1" in ran.stdout and '"_each" "1"' in text;
    for shot in shots {
        source = repo / f"dups_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"dups_{shot}.png");
        source.unlink();
    }
    print(
        f"DUPS PASS: {len(steps) - 1} steps, copies that grow and mirror on two axes, hidden and shown, images at "
            + "named points and along a path, made real, and a door copied into doors of their own"
    );
}

"""The twenty-second session: several documents open, switched between,
saved together, closed and reopened from the recent files; the selection's
menu on a right click; a brush's faces stepped through; a map written
without comments and in whole numbers."""
def docs_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["log", "menu"];
    for shot in shots {
        (repo / f"docs_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-docs-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/docs_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "docs.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The docs session failed: {output / 'docs.log'}";
        first = Path(home) / "scenes/one.map";
        second = Path(home) / "scenes/two.map";
        assert first.exists() and second.exists() , "Save all left a scene unsaved";
        text = first.read_text();
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        recent = (Path(home) / "overrides/studio_recent.txt").read_text().splitlines();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "two", "one", "next", "closed", "reopened", "drawn", "duplicated", "face", "stepped", "stepped_back"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'docs.log'}";
    }
    # Three documents: the level the game began in, and the two scenes, both edited.
    listed = [line for line in ran.stdout.splitlines() if line.startswith("studio: doc ")];
    assert "studio: doc passion/studio:one dirty=1 current=0" in listed , str(listed[:6]);
    assert "studio: doc passion/studio:two dirty=1 current=1" in listed and "studio: doc q1/e1m1 dirty=0 current=0" in listed;
    # Back in the first, the camera is where it was left there; next goes on to the second.
    assert steps["one"][0].startswith("passion/studio:one ") and camera_at(steps["one"]) == [100, 100, 300] , str(steps["one"][:2]);
    assert steps["next"][0].startswith("passion/studio:two ") , steps["next"][0];
    # Saved together, then the second closed: it is no longer listed, and another is shown.
    after = listed[3:];
    assert "studio: doc passion/studio:one dirty=0 current=1" in after or "studio: doc passion/studio:one dirty=0 current=0" in after , str(after);
    assert not [line for line in after if "studio:two" in line] , str(after);
    assert not steps["closed"][0].startswith("passion/studio:two ") , steps["closed"][0];
    # The recent files, newest first; the first of them opened again.
    said = [line[len("studio: recent "):] for line in ran.stdout.splitlines() if line.startswith("studio: recent ")];
    assert len(said) == 2 and said[0].endswith("two.map") and said[1].endswith("one.map") , str(said);
    assert steps["reopened"][0].startswith("passion/studio:two ") and "dirty=0" in steps["reopened"][0];
    assert "studio: log lines=5" in ran.stdout;
    # A right click on the selected box opens its menu; its second line duplicates the box.
    drawn = brushes(steps["drawn"]);
    copies = brushes(steps["duplicated"]);
    assert len(drawn) == 1 and len(copies) == 1 and copies != drawn , f"{drawn} {copies}";
    assert int(tally(steps["duplicated"]).split()[0].split("=")[1]) == int(tally(steps["drawn"]).split()[0].split("=")[1]) + 1;
    # One face picked; the next is another face of the same brush; the one before is the first again.
    face = faces(steps["face"]);
    stepped = faces(steps["stepped"]);
    assert len(face) == 1 and len(stepped) == 1 and face != stepped , f"{face} {stepped}";
    assert face[0].split("/")[0] == stepped[0].split("/")[0] and faces(steps["stepped_back"]) == face;
    # The map as asked: no numbered comments, and every plane point whole.
    assert "// brush" not in text and "// entity" not in text and '"classname" "worldspawn"' in text;
    for line in text.splitlines() {
        if line.startswith("( ") {
            for word in line.split(" [ ")[0].replace("(", " ").replace(")", " ").split()[:9] {
                assert "." not in word , line;
            }
        }
    }
    assert "ed_mapopts comments off" in kept and "ed_mapopts whole on" in kept , kept;
    assert len(recent) >= 2 and recent[0].endswith("one.map") , str(recent);
    for shot in shots {
        source = repo / f"docs_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"docs_{shot}.png");
        source.unlink();
    }
    print(
        f"DOCS PASS: {len(steps) - 1} steps, three documents open, saved together, one closed and reopened from "
            + "the recent files, the selection's menu, faces stepped, a map written bare and whole"
    );
}

"""How many things are hidden at a step."""
def hidden(lines: list[str]) -> int {
    found = [line for line in lines if line.startswith("mode=")];
    return int(found[0].split("hidden=")[1].split()[0]) if found else -1;
}

"""The twenty-first session: the level as a skill or a mode would spawn it,
a value replaced across entities, the logic audit, a pasted gadget with
names of its own, and a door fired by hand in a game held still."""
def entities_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "entities_skill.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-entities-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/entities_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "entities.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The entities session failed: {output / 'entities.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = [
        "made", "easy", "deathmatch", "everything", "flagged", "replaced", "pasted", "shut", "fired", "back"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'entities.log'}";
    }
    # One entity is left out on easy, one in deathmatch, none when everything is shown.
    assert hidden(steps["made"]) == 0 and hidden(steps["easy"]) == 1 and hidden(steps["deathmatch"]) == 1;
    assert hidden(steps["everything"]) == 0 , str(steps["everything"]);
    flagged = selected(steps["flagged"]);
    assert len(flagged) == 1 and "classname=monster_ogre" in flagged[0] and "spawnflags=1280" in flagged[0] , str(flagged);
    replaced = selected(steps["replaced"]);
    assert len(replaced) == 1 and "target=gate1" in replaced[0] , str(replaced);
    # The audit says what hangs; the plain check does not.
    assert "studio: finding item_health (vault) waits for vault, which nothing fires" in ran.stdout;
    # The pasted pair: a door named anew, and a button that fires that one.
    pasted = selected(steps["pasted"]);
    assert len(pasted) == 2 , str(pasted);
    door = [line for line in pasted if "classname=func_door" in line][0];
    button = [line for line in pasted if "classname=func_button" in line][0];
    assert "targetname=door2" in door and "target=door2" in button and "owns=1" in door , str(pasted);
    # Held still the door is shut; fired by its name and given time, it is not.
    assert played_word(steps["shut"], "doors").split(",")[0] == "closed" , str(steps["shut"]);
    assert "closed" not in played_word(steps["fired"], "doors").split(",")[0] , str(steps["fired"]);
    assert "studio: fired door1 1" in ran.stdout and "studio: fired nothing_named_this 0" in ran.stdout;
    assert "mode=brush" in steps["back"][-1];
    source = repo / "entities_skill.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "entities_skill.png");
    source.unlink();
    print(
        f"ENTITIES PASS: {len(steps) - 1} steps, the level as easy and deathmatch spawn it, a value replaced, the "
            + "logic audit, a pasted gadget with its own names, and a door fired by hand"
    );
}

"""A word of the line a played game prints about itself (`held`, `owed`,
`made`), and where its player is."""
def played_word(lines: list[str], key: str) -> str {
    found = [line for line in lines if line.startswith("play ")];
    return found[0].split(key + "=")[1].split()[0] if found else "";
}

def played_at(lines: list[str]) -> list[float] {
    return [float(part) for part in played_word(lines, "player").split(",")];
}

"""The twentieth session: the level lit coarsely, finely and not at all; a
game played from the studio held still, stepped by ticks and let run; and
the selection played alone."""
def play_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    with tempfile.TemporaryDirectory(prefix="qp-play-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/play_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "play.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The play session failed: {output / 'play.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "boxed", "quick", "full", "flat", "start", "hanging", "stepped", "still", "running", "back", "alone",
        "stopped"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'play.log'}";
    }
    # Lit coarsely there are fewer samples than lit finely, and without light none.
    assert 0 < lit(steps["quick"]) < lit(steps["full"]) and lit(steps["flat"]) == 0 , (
        f"{lit(steps['quick'])} {lit(steps['full'])} {lit(steps['flat'])}"
    );
    assert made(steps["boxed"]) == 2;
    # Held still, the player hangs where the camera was.
    start = played_at(steps["start"]);
    hanging = played_at(steps["hanging"]);
    assert played_word(steps["start"], "held") == "1" and played_word(steps["start"], "playing") == "1";
    assert start[0] == 0.0 and start[1] == 0.0 and 200.0 < start[2] < 300.0 and hanging == start , f"{start} {hanging}";
    # Thirty ticks are half a second of falling; then it hangs again.
    stepped = played_at(steps["stepped"]);
    assert stepped[2] < start[2] - 20.0 and played_word(steps["stepped"], "owed") == "0" , f"{start} {stepped}";
    assert played_at(steps["still"]) == stepped , str(steps["still"]);
    assert played_word(steps["running"], "held") == "0";
    assert "mode=brush" in steps["back"][-1] and made(steps["back"]) == 2;
    # Played alone, the box is all the level is built from; back in the studio the whole scene is.
    assert played_word(steps["alone"], "made") == "1" and played_word(steps["start"], "made") == "2" , str(steps["alone"]);
    assert made(steps["stopped"]) == 2 and len(brushes(steps["stopped"])) == 1;
    assert "ed_build full" in kept , kept;
    print(
        f"PLAY PASS: {len(steps) - 1} steps, the level lit three ways, a played game held still and stepped by "
            + "ticks, and the selection played alone"
    );
}

"""How many rows the scene list has at a step."""
def tree_rows(lines: list[str]) -> int {
    found = [line for line in lines if line.startswith("tree rows=")];
    return int(found[0].split("=")[1]) if found else -1;
}

"""The nineteenth session: a group shown as outlines only, locked, skipped
by builds, tinted and hidden, and its row in the scene list."""
def groups_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["grey", "tinted", "hidden"];
    for shot in shots {
        (repo / f"groups_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-groups-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/groups_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "groups.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The groups session failed: {output / 'groups.log'}";
        saved = Path(home) / "scenes/groups.map";
        assert saved.exists() , "Save wrote no map";
        text = saved.read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "grouped", "grey", "through", "locked", "passed", "taken", "skipped", "tinted", "opened", "hidden"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'groups.log'}";
    }
    group = selected(steps["grouped"]);
    assert len(group) == 1 and "_group_name=pillar" in group[0] and "owns=1" in group[0] , str(group);
    assert made(steps["grouped"]) == 2;
    # As outlines only it is out of the level, and a click where it stands takes the floor.
    assert "_view=grey" in selected(steps["grey"])[0] and made(steps["grey"]) == 1 , str(steps["grey"]);
    floor = brushes(steps["through"]);
    assert len(floor) == 1 and brush_box(floor[0])[1][2] == 0 and not selected(steps["through"]) , str(steps["through"]);
    # Locked it is built, and still passed by.
    locked = selected(steps["locked"])[0];
    assert "_locked=1" in locked and "_view" not in locked and made(steps["locked"]) == 2 , locked;
    assert brushes(steps["passed"]) == floor , str(steps["passed"]);
    # Unlocked, the same click takes its brush.
    taken = brushes(steps["taken"]);
    assert len(taken) == 1 and brush_box(taken[0]) == [[-288, 112, 0], [-96, 208, 64]] , str(taken);
    assert "owner=func_group" in taken[0];
    # Skipped by builds.
    assert "_skip=1" in selected(steps["skipped"])[0] and made(steps["skipped"]) == 1 , str(steps["skipped"]);
    tinted = selected(steps["tinted"])[0];
    assert "_tint=255 128 0" in tinted and "_skip" not in tinted and made(steps["tinted"]) == 2 , tinted;
    # Opened, the group's row has its brush under it.
    assert tree_rows(steps["opened"]) == tree_rows(steps["tinted"]) + 1 , f"{steps['tinted']} {steps['opened']}";
    assert "_view=hidden" in selected(steps["hidden"])[0] and made(steps["hidden"]) == 1;
    assert '"_view" "hidden"' in text and '"_tint" "255 128 0"' in text , text[:600];
    for shot in shots {
        source = repo / f"groups_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"groups_{shot}.png");
        source.unlink();
    }
    print(
        f"GROUPS PASS: {len(steps) - 1} steps, a group shown as outlines, locked, skipped by builds, tinted and "
            + "hidden, with its row in the scene list"
    );
}

"""A word of a step's line about the views (`span`, `layout`, ...)."""
def view_word(lines: list[str], key: str) -> str {
    found = [line for line in lines if line.startswith("views ")];
    return found[0].split(key + "=")[1].split()[0] if found else "";
}

"""Where the 3D camera stands at a step."""
def camera_at(lines: list[str]) -> list[int] {
    found = [line for line in lines if line.startswith("camera ")];
    return [int(part) for part in found[0].split()[1:4]];
}

"""The eighteenth session: the layouts, the ruler, zoom, names, remembered
views, a backdrop picture, and the camera swung round and taken behind a
face; then the studio opened again with its settings."""
def views_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["two", "column", "ruler", "backdrop"];
    for shot in shots {
        (repo / f"views_{shot}.png").unlink(missing_ok=True);
    }
    (output / "backdrop.png").write_bytes(checker_png(64));
    with tempfile.TemporaryDirectory(prefix="qp-views-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/views_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "views.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The views session failed: {output / 'views.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
        again = subprocess.run(
            [str(binary), "+edit", "+wait", "+wait", "+ed_dump", "again", "+quit"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "views_again.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Opening the studio again failed: {output / 'views_again.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = ["two", "three", "column", "measured", "far", "nearer", "back", "laid", "before", "swung", "behind"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'views.log'}";
    }
    # Two views, three, and four with the axis views in a column.
    shown = [[line for line in steps[name] if line.startswith("view ")][0] for name in ["two", "three", "column"]];
    assert shown[0].endswith(" of 2") and shown[1].endswith(" of 3") and shown[2].endswith(" of 4") , str(shown);
    assert view_word(steps["column"], "layout") == "4b" and view_word(steps["measured"], "layout") == "4";
    assert view_word(steps["measured"], "ruler") == "1" and view_word(steps["measured"], "span") == "1024";
    # Zoom sets every axis view, then = brings the one under the pointer twice as near.
    assert view_word(steps["far"], "span") == "2048" and view_word(steps["nearer"], "span") == "1024" , str(steps["nearer"]);
    # The view remembered first is gone back to.
    assert camera_at(steps["back"]) == camera_at(steps["measured"]) and camera_at(steps["back"])[1] != -600 , str(
        steps["back"]
    );
    assert view_word(steps["back"], "names") == "1";
    # The world keeps the view still remembered and the picture's place; the forgotten one is gone.
    world = selected(steps["laid"]);
    assert len(world) == 1 and "_view_there=0 -600 400 90 -30" in world[0] and "_view_here" not in world[0] , str(world);
    assert "_backdrop=.jac/screenshots/studio/backdrop.png" in world[0] , world[0];
    assert view_word(steps["laid"], "backdrop") == "top,0,0,2.0,150" , str(steps["laid"]);
    # Swung a quarter round the box, the camera is as far from its middle as it was.
    before = camera_at(steps["before"]);
    swung = camera_at(steps["swung"]);
    middle = [-192, 160, 32];
    far_before = sum([(before[axis] - middle[axis]) ** 2 for axis in range(3)]) ** 0.5;
    far_after = sum([(swung[axis] - middle[axis]) ** 2 for axis in range(3)]) ** 0.5;
    assert before == [-192, -340, 32] and abs(far_before - far_after) < 3.0 , f"{before} {swung}";
    # It faced along +y; turned a quarter to face -x, it stands on the +x side.
    assert abs(swung[0] - 308) <= 3 and abs(swung[1] - 160) <= 3 and swung[2] == 32 , str(swung);
    # Behind the top face: under it, on the line through its middle.
    under = camera_at(steps["behind"]);
    assert under[0] == -192 and under[1] == 160 and under[2] < 0 , str(under);
    assert "ed_ruler on" in kept and "ed_names on" in kept and "ed_layout 4" in kept , kept;
    back = studio_steps(again.stdout)["again"];
    assert view_word(back, "names") == "1" and view_word(back, "layout") == "4" , str(back);
    for shot in shots {
        source = repo / f"views_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"views_{shot}.png");
        source.unlink();
    }
    print(
        f"VIEWS PASS: {len(steps) - 1} steps, two, three and four views, a ruler, zoom, names, remembered views, "
            + "a backdrop, and the camera swung round a box and taken behind its top"
    );
}

"""How many brushes the level was built from at a step."""
def made(lines: list[str]) -> int {
    found = [line for line in lines if line.startswith("made brushes=")];
    return int(found[0].split("=")[1]) if found else -1;
}

"""The seventeenth session: walls, a cone and a pushed-out brush stood on a
picked face, side flags, and a digger that leaves a shaft in what is built."""
def faces_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["walls", "cone", "dug"];
    for shot in shots {
        (repo / f"faces_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-faces-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/faces_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "faces.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The faces session failed: {output / 'faces.log'}";
        saved = Path(home) / "scenes/faces.map";
        assert saved.exists() , "Save wrote no map";
        text = saved.read_text();
    }
    steps = studio_steps(ran.stdout);
    names = ["drawn", "picked", "walled", "coned", "extruded", "flagged", "inner", "dug", "filled", "dug_again"];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'faces.log'}";
    }
    box = brush_box(brushes(steps["drawn"])[0]);
    assert box == [[-288, 112, 0], [-96, 208, 64]] , str(box);
    # The floor and the box.
    assert made(steps["drawn"]) == 2 , str(steps["drawn"]);
    assert len(faces(steps["picked"])) == 1 , str(steps["picked"]);
    # Four walls round the top's edge, thirty-two high and sixteen thick, inside its outline.
    walls = [brush_box(line) for line in brushes(steps["walled"])];
    assert len(walls) == 4 and made(steps["walled"]) == 6 , str(steps["walled"]);
    for wall in walls {
        assert wall[0][2] == 64 and wall[1][2] == 96 , str(wall);
        assert wall[0][0] >= -288 and wall[1][0] <= -96 and wall[0][1] >= 112 and wall[1][1] <= 208 , str(wall);
        assert min(wall[1][0] - wall[0][0], wall[1][1] - wall[0][1]) == 16 , str(wall);
    }
    # A cone: the top for a base, a point forty-eight above its middle.
    cone = brushes(steps["coned"]);
    assert len(cone) == 1 and "sides=5" in cone[0] , str(cone);
    assert brush_box(cone[0]) == [[-288, 112, 64], [-96, 208, 112]] , cone[0];
    # The face pushed out: a brush of its own on top of the first.
    pushed = brushes(steps["extruded"]);
    assert len(pushed) == 1 and brush_box(pushed[0]) == [[-288, 112, 64], [-96, 208, 96]] , str(pushed);
    assert "mode=brush" in steps["extruded"][-1] and made(steps["extruded"]) == 3;
    # Detail on every side of it, and a surface flag on the one face picked afterwards.
    flagged = faces(steps["flagged"]);
    assert len(flagged) == 1 and "contents=134217728 flags=4 value=0" in flagged[0] , str(flagged);
    assert " 134217728 4 0" in text and text.count(" 134217728 0 0") == 5 , "The map lost the side flags";
    # A box inside the first, then made a digger: the first is built as four pieces round a shaft.
    inner = brush_box(brushes(steps["inner"])[0]);
    assert inner == [[-240, 128, 0], [-144, 176, 64]] and made(steps["inner"]) == 4 , f"{inner} {steps['inner']}";
    dug = selected(steps["dug"]);
    assert len(dug) == 1 and "_digger=1" in dug[0] and "owns=1" in dug[0] , str(dug);
    assert made(steps["dug"]) == 6 , str(steps["dug"]);
    # The document still holds the four brushes it did.
    assert tally(steps["dug"]).startswith("brushes=4 ") , tally(steps["dug"]);
    assert made(steps["filled"]) == 4 and "_digger" not in selected(steps["filled"])[0];
    assert made(steps["dug_again"]) == 6 and '"_digger" "1"' in text;
    for shot in shots {
        source = repo / f"faces_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"faces_{shot}.png");
        source.unlink();
    }
    print(
        f"FACES PASS: {len(steps) - 1} steps, walls, a cone and a pushed-out brush on a picked face, side flags "
            + "kept in the map, and a digger's shaft in what is built"
    );
}

"""The line of a step that names the kept sets."""
def kept_sets(lines: list[str]) -> str {
    found = [line for line in lines if line.startswith("sets=")];
    return found[0][5:] if found else "";
}

"""The sixteenth session: clicks through two stacked boxes to the floor,
steps to the owner and back to its brushes, a brush by number, kept sets, a
swap and a tour; then the saved map opened again with its sets."""
def select_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["through", "swapped"];
    for shot in shots {
        (repo / f"select_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-select-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/select_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "select.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The select session failed: {output / 'select.log'}";
        saved = Path(home) / "scenes/picks.map";
        assert saved.exists() , "Save wrote no map";
        text = saved.read_text();
        again = subprocess.run(
            [
                str(binary), "+edit", "+ed_open", str(saved), "+ed_recall", "walls", "+ed_dump", "reopened",
                "+quit"
            ],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "select_reopen.log").write_text(again.stdout + again.stderr);
        assert again.returncode == 0 , f"Reopening the map failed: {output / 'select_reopen.log'}";
    }
    steps = studio_steps(ran.stdout);
    names = [
        "first", "second", "third", "round", "numbered", "owner", "children", "picked", "pair", "swapped", "toured",
        "onward"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'select.log'}";
    }
    # The first click picks the box on top; the next two go down through it.
    first = brushes(steps["first"]);
    second = brushes(steps["second"]);
    third = brushes(steps["third"]);
    assert len(first) == 1 and len(second) == 1 and len(third) == 1 , f"{first} {second} {third}";
    upper = brush_box(first[0]);
    lower = brush_box(second[0]);
    assert upper == [[-288, 112, 96], [-96, 208, 160]] and lower == [[-288, 112, 0], [-96, 208, 64]] , f"{upper} {lower}";
    assert brush_box(third[0])[1][2] == 0 , third[0];
    assert brushes(steps["round"]) == first , str(steps["round"]);
    # Entity 0's third brush is the lower box.
    assert brushes(steps["numbered"]) == second , str(steps["numbered"]);
    assert "sets=upper:1" in "sets=" + kept_sets(steps["numbered"]);
    # Its owner is the world, whose brushes are the floor and the two boxes.
    owner = selected(steps["owner"]);
    assert len(owner) == 1 and "classname=worldspawn" in owner[0] and not brushes(steps["owner"]) , str(owner);
    assert len(brushes(steps["children"])) == 3 and not selected(steps["children"]) , str(steps["children"]);
    assert brushes(steps["picked"]) == first and kept_sets(steps["picked"]) == "upper:1,walls:3";
    # The player start and the upper box, swapped: each stands where the other's middle was.
    pair = selected(steps["pair"]);
    assert len(pair) == 1 and "origin=0 0 24" in pair[0] and brushes(steps["pair"]) == first , str(steps["pair"]);
    swapped = selected(steps["swapped"]);
    assert len(swapped) == 1 and "origin=-192 160 128" in swapped[0] , str(swapped);
    moved = brush_box(brushes(steps["swapped"])[0]);
    assert moved == [[-96, -48, -8], [96, 48, 56]] , str(moved);
    # The tour looks at one, then the other: the camera moves each time.
    cameras = [
        [line for line in steps[name] if line.startswith("camera ")][0] for name in ["swapped", "toured", "onward"]
    ];
    assert cameras[0] != cameras[1] and cameras[1] != cameras[2] , str(cameras);
    # The sets are in the map as places in it, and come back when it is opened.
    assert '"_set_upper" "0:1"' in text and '"_set_walls" "0:0 0:1 0:2"' in text , text[:400];
    back = studio_steps(again.stdout)["reopened"];
    assert kept_sets(back) == "upper:1,walls:3" and len(brushes(back)) == 3 , str(back);
    for shot in shots {
        source = repo / f"select_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"select_{shot}.png");
        source.unlink();
    }
    print(
        f"SELECT PASS: {len(steps) - 1} steps, clicks through two boxes to the floor, the owner and its brushes, "
            + "a brush by number, sets kept and reopened, a swap and a tour"
    );
}

"""The line of a step that tells which handles show and how they snap."""
def handles(lines: list[str]) -> str {
    found = [line for line in lines if line.startswith("handles=")];
    return found[0] if found else "";
}

"""The fifteenth session: a box turned by the knob on its ring, stretched by
a handle about its middle and about a pivot, inflated, and grouped with a
pivot of its own."""
def transform_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    shots = ["rings", "turning", "sized", "pivot"];
    for shot in shots {
        (repo / f"transform_{shot}.png").unlink(missing_ok=True);
    }
    with tempfile.TemporaryDirectory(prefix="qp-transform-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/transform_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        (output / "transform.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The transform session failed: {output / 'transform.log'}";
        kept = (Path(home) / "overrides/studio.cfg").read_text();
    }
    steps = studio_steps(ran.stdout);
    names = [
        "drawn", "rings", "turned", "slanted", "boxes", "doubled", "pivoted", "grown", "inflated", "grouped",
        "swung", "left"
    ];
    for name in names {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'transform.log'}";
    }
    # A box twice as long as it is deep, with its near corner where the pivot will go.
    drawn = brushes(steps["drawn"]);
    assert len(drawn) == 1 , str(steps["drawn"]);
    box = brush_box(drawn[0]);
    assert box == [[-288, 112, 0], [-96, 208, 64]] , str(box);
    assert "handles=move" in handles(steps["drawn"]) and "anglesnap=15" in handles(steps["drawn"]);
    assert "handles=turn" in handles(steps["rings"]) , handles(steps["rings"]);
    # The knob taken a quarter of the way round its ring: the box stands the other way about its middle.
    turned = brush_box(brushes(steps["turned"])[0]);
    assert turned == [[-240, 64, 0], [-144, 256, 64]] , str(turned);
    # With turns snapping to forty-five degrees, a drag of about forty lands there.
    slanted = brush_box(brushes(steps["slanted"])[0]);
    assert "anglesnap=45" in handles(steps["slanted"]);
    for axis in [0, 1] {
        assert abs(slanted[1][axis] - slanted[0][axis] - 204) <= 2 , str(slanted);
    }
    assert slanted[0][2] == 0 and slanted[1][2] == 64 and "sides=6" in brushes(steps["slanted"])[0];
    assert "handles=size" in handles(steps["boxes"]) , handles(steps["boxes"]);
    # The red box pulled out by the arm's length: twice as long, about the middle.
    doubled = brush_box(brushes(steps["doubled"])[0]);
    assert doubled == [[-384, 112, 0], [0, 208, 64]] , str(doubled);
    # About a pivot at the near corner, the same pull grows it one way only.
    assert "pivot=-288,112,0" in handles(steps["pivoted"]) , handles(steps["pivoted"]);
    grown = brush_box(brushes(steps["grown"])[0]);
    assert grown == [[-288, 112, 0], [96, 208, 64]] , str(grown);
    inflated = brush_box(brushes(steps["inflated"])[0]);
    assert inflated == [[-304, 96, -16], [-80, 224, 80]] , str(inflated);
    assert "pivot=none" in handles(steps["inflated"]);
    # The group's own pivot is a field of the group, and went with it when it moved.
    grouped = selected(steps["grouped"]);
    assert len(grouped) == 1 and "_group_name=pillar" in grouped[0] and "_center=16 0 0" in grouped[0] , str(grouped);
    assert "owns=1" in grouped[0];
    # Turned about that pivot, the pivot stays where it is.
    swung = selected(steps["swung"]);
    assert len(swung) == 1 and "_center=16 0 0" in swung[0] , str(swung);
    assert tally(steps["swung"]) != tally(steps["grouped"]);
    left = handles(steps["left"]);
    assert "handles=move" in left and "texlock=0" in left and "anglesnap=45" in left , left;
    assert "ed_anglesnap 45" in kept and "ed_texlock off" in kept , kept;
    for shot in shots {
        source = repo / f"transform_{shot}.png";
        check_capture(source, 6);
        shutil.copyfile(source, output / f"transform_{shot}.png");
        source.unlink();
    }
    print(
        f"TRANSFORM PASS: {len(steps) - 1} steps, a box turned by its ring, sized by a handle about its middle and "
            + "about a pivot, inflated, and grouped with a pivot of its own"
    );
}

"""A small PNG: `size` texels a side, a checker of two colours."""
def checker_png(size: int = 4) -> bytes {
    import zlib;
    import struct;
    rows = b"";
    for y in range(size) {
        rows += b"\x00";
        for x in range(size) {
            rows += bytes([200, 120, 40, 255]) if (x + y) % 2 == 0 else bytes([60, 40, 20, 255]);
        }
    }
    def chunk(kind: bytes, data: bytes) -> bytes {
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF);
    }
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"");
}

"""The fourteenth session: materials at their true size, from Quake III's
archives and from the project's own image files."""
def material_session(repo: Path, binary: Path, env: dict[str, str], output: Path) {
    (repo / "material_files.png").unlink(missing_ok=True);
    with tempfile.TemporaryDirectory(prefix="qp-material-") as home {
        env["QP_CONFIG_DIR"] = home;
        env["QP_OVERRIDES"] = home + "/overrides";
        env["QP_SCENES"] = home + "/scenes";
        env["QP_TEXTURES"] = home + "/textures";
        (Path(home) / "textures").mkdir();
        (Path(home) / "textures/crate.png").write_bytes(checker_png(4));
        ran = subprocess.run(
            [str(binary), "+ed_exec", "scripts/studio/material_session.cfg"],
            cwd=repo,
            env=env,
            capture_output=True,
            text=True,
            timeout=300
        );
        env.pop("QP_TEXTURES");
        (output / "material.log").write_text(ran.stdout + ran.stderr);
        assert ran.returncode == 0 , f"The material session failed: {output / 'material.log'}";
    }
    steps = studio_steps(ran.stdout);
    for name in ["arena", "own", "clicked"] {
        assert name in steps and steps[name] , f"The session never reached '{name}': {output / 'material.log'}";
    }
    # A 256 by 512 image once across 128 units: half a unit a texel one way, a quarter the other.
    arena = faces(steps["arena"]);
    assert len(arena) == 1 and "material=q3:textures/base_wall/archpipe2_k_tall3fin" in arena[0] , str(arena);
    assert "scale=0.5,0.25" in arena[0] , arena[0];
    # The project's 4-texel image across a side 128 by 96: thirty-two units a texel, and twenty-four.
    homemade = faces(steps["own"]);
    assert len(homemade) == 1 and "material=file:crate.png" in homemade[0] and "scale=32.0,24.0" in homemade[0] , str(homemade);
    # A click on its picture in the Materials tab gives it to the face then picked.
    clicked = faces(steps["clicked"]);
    assert len(clicked) == 1 and clicked[0].startswith("face #3/2 material=file:crate.png") , str(clicked);
    # Both are in the archives or the folder: the check does not call them missing.
    assert "No archive holds the material" not in ran.stdout;
    source = repo / "material_files.png";
    check_capture(source, 6);
    shutil.copyfile(source, output / "material_files.png");
    source.unlink();
    print(f"MATERIAL PASS: {len(steps) - 1} steps, a Quake III texture and a project image fitted at their true sizes");
}

"""Run some sessions one after another, each as a run of this script with
`--only`. Answers (name, whether it passed, what it said last) for each."""
def run_lane(names: list[str], binary: Path) -> list[tuple[str, bool, str]] {
    told: list[tuple[str, bool, str]] = [];
    for name in names {
        ran = subprocess.run(
            ["jac", "run", str(Path(__file__).resolve()), "--binary", str(binary), "--only", name],
            cwd=Path(__file__).resolve().parent.parent,
            capture_output=True,
            text=True,
            timeout=1800
        );
        said = [line for line in (ran.stdout + ran.stderr).splitlines() if line.strip()];
        # What a session says of itself: that it passed, and what it had to leave out.
        result = [line for line in said if " PASS: " in line or " SKIPPED " in line];
        passed = ran.returncode == 0 and len([line for line in result if " PASS: " in line]) > 0;
        told.append((name, passed, "\n".join(result) if passed else "\n".join(said[-14:])));
    }
    return told;
}

"""Run every session, `jobs` lanes at a time. Answers how many failed."""
def run_lanes(names: list[str], binary: Path, jobs: int) -> int {
    # Sessions that write the same folder of the repository go in one lane.
    together = [name for name in ["assets", "terrain", "tidy"] if name in names];
    lanes = [[name] for name in names if name not in together];
    if together {
        lanes.insert(0, together);
    }
    began = time.time();
    failed: list[str] = [];
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool {
        waiting = [pool.submit(run_lane, lane, binary) for lane in lanes];
        for one in waiting {
            for (name, passed, said) in one.result() {
                print(said if passed else f"{name} FAILED:\n{said}", flush=True);
                if not passed {
                    failed.append(name);
                }
            }
        }
    }
    print(
        f"{len(names) - len(failed)} of {len(names)} sessions passed in {int(time.time() - began)} s, {jobs} at a time"
            + (": failed " + ", ".join(failed) if failed else "")
    );
    return len(failed);
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
    sessions = {
        "scene": scene_session,
        "tools": tools_session,
        "logic": logic_session,
        "build": build_session,
        "images": images_session,
        "assets": assets_session,
        "handy": handy_session,
        "terrain": terrain_session,
        "patch": patch_session,
        "tidy": tidy_session,
        "draw": draw_session,
        "material": material_session,
        "transform": transform_session,
        "select": select_session,
        "faces": faces_session,
        "views": views_session,
        "groups": groups_session,
        "play": play_session,
        "entities": entities_session,
        "docs": docs_session,
        "dups": dups_session,
        "shapes": shapes_session,
        "land": land_session,
        "quilt": quilt_session,
        "controls": controls_session,
        "wrap": wrap_session,
        "settings": settings_session,
        "marks": marks_session,
        "bake": bake_session,
        "steps": steps_session,
        "project": project_session,
        "outside": outside_session,
        "depth": depth_session,
        "layers": layers_session,
        "sweep": sweep_session,
        "live": live_session,
        "model": model_session,
        "rig": rig_session,
        "drop": drop_session,
        "links": links_session,
        "touch": touch_session,
        "games": games_session,
        "shader": shader_session,
        "sounds": sounds_session,
        "nest": nest_session,
        "skin": skin_session,
        "preview": preview_session,
        "lay": lay_session,
        "lean": lean_session,
        "arms": arms_session,
        "bones": bones_session,
        "figure": figure_session,
        "district": district_session,
        "float": float_session,
        "nav": nav_session,
        "restrict": restrict_session,
        "finds": finds_session,
        "whole": whole_session,
        "playview": playview_session,
        "modelfiles": modelfiles_session,
        "stuck": stuck_session,
        "turned": turned_session,
        "repack": repack_session,
        "finding": finding_session,
        "treebox": treebox_session,
        "meshcut": meshcut_session,
        "convert": convert_session
    };
    if "--jobs" in sys.argv {
        failed = run_lanes(["shell"] + list(sessions.keys()), binary, int(sys.argv[sys.argv.index("--jobs") + 1]));
        print(f"Screenshots and logs: {output}");
        if failed > 0 {
            sys.exit(1);
        }
        return;
    }
    only_shell = "--only" in sys.argv and sys.argv[sys.argv.index("--only") + 1] == "shell";
    if "--only" in sys.argv and not only_shell {
        # One session alone, while working on what it covers.
        wanted = sys.argv[sys.argv.index("--only") + 1];
        assert wanted in sessions , f"No session '{wanted}': " + ", ".join(sessions.keys());
        alone = dict(os.environ);
        for key in ["DYLD_LIBRARY_PATH", "LD_LIBRARY_PATH"] {
            alone[key] = str(repo / "vendor") + (os.pathsep + alone[key] if alone.get(key) else "");
        }
        alone["QP_GAME"] = "q1";
        alone["QP_MAP"] = "e1m1";
        sessions[wanted](repo, binary, alone, output);
        return;
    }
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
    if only_shell {
        return;
    }
    scene_session(repo, binary, env, output);
    tools_session(repo, binary, env, output);
    logic_session(repo, binary, env, output);
    build_session(repo, binary, env, output);
    images_session(repo, binary, env, output);
    assets_session(repo, binary, env, output);
    handy_session(repo, binary, env, output);
    terrain_session(repo, binary, env, output);
    patch_session(repo, binary, env, output);
    tidy_session(repo, binary, env, output);
    draw_session(repo, binary, env, output);
    material_session(repo, binary, env, output);
    transform_session(repo, binary, env, output);
    select_session(repo, binary, env, output);
    faces_session(repo, binary, env, output);
    views_session(repo, binary, env, output);
    groups_session(repo, binary, env, output);
    play_session(repo, binary, env, output);
    entities_session(repo, binary, env, output);
    docs_session(repo, binary, env, output);
    dups_session(repo, binary, env, output);
    shapes_session(repo, binary, env, output);
    land_session(repo, binary, env, output);
    quilt_session(repo, binary, env, output);
    controls_session(repo, binary, env, output);
    wrap_session(repo, binary, env, output);
    settings_session(repo, binary, env, output);
    marks_session(repo, binary, env, output);
    bake_session(repo, binary, env, output);
    steps_session(repo, binary, env, output);
    project_session(repo, binary, env, output);
    outside_session(repo, binary, env, output);
    depth_session(repo, binary, env, output);
    layers_session(repo, binary, env, output);
    sweep_session(repo, binary, env, output);
    live_session(repo, binary, env, output);
    model_session(repo, binary, env, output);
    rig_session(repo, binary, env, output);
    drop_session(repo, binary, env, output);
    links_session(repo, binary, env, output);
    touch_session(repo, binary, env, output);
    games_session(repo, binary, env, output);
    shader_session(repo, binary, env, output);
    sounds_session(repo, binary, env, output);
    nest_session(repo, binary, env, output);
    skin_session(repo, binary, env, output);
    preview_session(repo, binary, env, output);
    lay_session(repo, binary, env, output);
    lean_session(repo, binary, env, output);
    arms_session(repo, binary, env, output);
    bones_session(repo, binary, env, output);
    figure_session(repo, binary, env, output);
    district_session(repo, binary, env, output);
    float_session(repo, binary, env, output);
    nav_session(repo, binary, env, output);
    restrict_session(repo, binary, env, output);
    finds_session(repo, binary, env, output);
    whole_session(repo, binary, env, output);
    playview_session(repo, binary, env, output);
    modelfiles_session(repo, binary, env, output);
    stuck_session(repo, binary, env, output);
    turned_session(repo, binary, env, output);
    repack_session(repo, binary, env, output);
    finding_session(repo, binary, env, output);
    treebox_session(repo, binary, env, output);
    meshcut_session(repo, binary, env, output);
    convert_session(repo, binary, env, output);
    print(f"Screenshots and logs: {output}");
}

with entry {
    main();
}
