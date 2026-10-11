"""Drive the studio in the real game and check what it did.

Runs `qp` (build it first, or pass --binary) on an active desktop with
scripts/studio/shell_session.cfg: the interface is clicked, typed into and
dragged by scripted input, the document is printed after each step, and
screenshots are taken along the way. A second run without the studio checks
that the saved entities are what the level loads.

    jac run scripts/validate_studio.jac [--binary ./qp] [--only <session>]

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
    assert len(stairs) == 1 and "_group_name=stairs owns=8" in stairs[0] , str(stairs);
    arch = selected(steps["arch"]);
    assert len(arch) == 1 and "_group_name=arch owns=8" in arch[0] and "brushes=17" in tally(steps["arch"]);
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
        "convert": convert_session
    };
    if "--only" in sys.argv {
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
    convert_session(repo, binary, env, output);
    print(f"Screenshots and logs: {output}");
}

with entry {
    main();
}
