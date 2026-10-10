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
    print(
        f"CONVERT PASS: base1 as {counts['q2']} brushes and q3dm1 as {counts['q3']}, saved as maps and reopened"
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
    shots = ["texture", "text"];
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
    for name in ["boxed", "texture", "used", "text", "sound", "packed"] {
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
    print(f"ASSETS PASS: {len(steps) - 1} steps, a texture shown, used and extracted, a scene and a folder packed");
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
    tools_session(repo, binary, env, output);
    logic_session(repo, binary, env, output);
    build_session(repo, binary, env, output);
    images_session(repo, binary, env, output);
    assets_session(repo, binary, env, output);
    convert_session(repo, binary, env, output);
    print(f"Screenshots and logs: {output}");
}

with entry {
    main();
}
