import os;
import from engine.console.shell { Shell }
import from engine.console.console { Console, console_rows, console_visible }
import from engine.input.keys { Keyboard, key_event_commands, key_canonical_name }
import from engine.input.input { Controls, Intent }
import from engine.core.preferences { Preferences, legacy_settings }
import from games.controls { control_actions, binding_layer }

"""Cbuf_Execute as the app runs it: the shell's own commands, then the keys'
and the input layer's."""
def run_config(shell: Shell, keyboard: Keyboard, controls: Controls, text: str) -> list[list[str]] {
    shell.insert_text(text);
    others: list[list[str]] = [];
    while True {
        args = shell.next_command();
        if not args {
            break;
        }
        forwarded = shell.run(args);
        if forwarded is None {
            continue;
        }
        if forwarded.owner == "keys" {
            keyboard.command(shell, args);
        } elif forwarded.owner == "input" {
            controls.command(shell, args);
        } else {
            others.append(args);
        }
    }
    return others;
}

def fresh_input() -> tuple[Shell, Keyboard, Controls] {
    shell = Shell();
    shell.boot();
    keyboard = Keyboard();
    keyboard.declare(shell);
    controls = Controls();
    controls.declare(shell);
    return (shell, keyboard, controls);
}

glob Q1_DEFAULTS: str = "//\n// load keybindings\nunbindall\n\nbind\tALT\t\t\t\t+strafe\nbind\t,\t\t\t\t+moveleft\nbind\ta\t\t\t\t+lookup\nbind\tSPACE\t\t\t+jump \nbind\tENTER\t\t\t+jump\nbind\t1\t\t\t\t\"impulse 1\"\nbind\t/\t\t\t\t\"impulse 10\"\t\t// change weapon\nalias zoom_in \"sensitivity 2;fov 90;wait;fov 70\"\nbind F11 zoom_in\nbind\tMOUSE1\t\t+attack\nbind\t~\t\t\t\t\"toggleconsole\"\nbind\t`\t\t\t\t\"toggleconsole\"\nviewsize \t\t100\nsensitivity \t3\n";

test "key names follow Key_StringToKeynum: characters themselves, names in any case" {
    assert key_canonical_name("A") == "a" and key_canonical_name("tab") == "TAB";
    assert key_canonical_name(";") == "SEMICOLON" and key_canonical_name("mouse1") == "MOUSE1";
    keyboard = Keyboard();
    keyboard.boot();
    assert keyboard.key("uparrow") is not None and keyboard.key("KP_ENTER") is not None;
    assert keyboard.key("NOSUCHKEY") is None and keyboard.key("~") is None;
    made = keyboard.key("~", make=True);
    assert made is not None and made.name == "~";
    assert keyboard.key("~") is made;
}

test "a game's default.cfg binds keys, and the layer and the console rebind them" {
    parts = fresh_input();
    shell = parts[0];
    keyboard = parts[1];
    controls = parts[2];
    others = run_config(shell, keyboard, controls, Q1_DEFAULTS);
    assert keyboard.keys_for("+jump") == ["ENTER", "SPACE"];
    assert keyboard.keys_for("impulse 10") == ["/"];
    assert keyboard.keys_for("toggleconsole") == ["`", "~"];
    assert keyboard.keys_for("zoom_in") == ["F11"];
    # Unknown commands and cvars print, as the originals did.
    assert "Unknown command \"viewsize\"" in shell.log.lines;
    assert others == [];
    run_config(shell, keyboard, controls, binding_layer("q1", True));
    assert keyboard.keys_for("+moveleft") == [",", "a"] and keyboard.keys_for("+lookup") == [];
    assert keyboard.keys_for("impulse 12") == ["MWHEELUP"];
    run_config(shell, keyboard, controls, "bind x \"+attack\"; unbind MOUSE1; bind semicolon echo hi");
    assert keyboard.keys_for("+attack") == ["x"] and keyboard.keys_for("echo hi") == ["SEMICOLON"];
    run_config(shell, keyboard, controls, "bind x");
    assert shell.log.lines[-1] == "\"x\" = \"+attack\"";
    run_config(shell, keyboard, controls, "bind NOSUCHKEY +jump");
    assert shell.log.lines[-1] == "\"NOSUCHKEY\" isn't a valid key";
    lines = keyboard.binding_lines();
    assert lines[0] == "unbindall" and "bind x \"+attack\"" in lines and "bind SEMICOLON \"echo hi\"" in lines;
    assert "bind \"/\" \"impulse 10\"" in lines;
    # The written lines rebuild the same bindings.
    again = fresh_input();
    run_config(again[0], again[1], again[2], "\n".join(lines));
    assert again[1].binding_lines() == lines;
    run_config(shell, keyboard, controls, "unbindall");
    assert keyboard.binding_lines() == ["unbindall"];
}

test "button bindings send their release; other bindings run on the press" {
    assert key_event_commands("+attack", "MOUSE1", True) == ["+attack MOUSE1"];
    assert key_event_commands("+attack", "MOUSE1", False) == ["-attack MOUSE1"];
    assert key_event_commands("impulse 10", "/", True) == ["impulse 10"];
    assert key_event_commands("impulse 10", "/", False) == [];
    assert key_event_commands("+attack; +speed", "CTRL", False) == ["-attack CTRL", "-speed CTRL"];
    assert key_event_commands("+attack; echo fire", "CTRL", True) == ["+attack CTRL", "echo fire"];
    assert key_event_commands("+jump", "/", True) == ["+jump \"/\""];
    assert key_event_commands("", "x", True) == [];
}

test "buttons build the move as CL_BaseMove: walking, running and two keys on one button" {
    parts = fresh_input();
    shell = parts[0];
    keyboard = parts[1];
    controls = parts[2];
    run_config(shell, keyboard, controls, "+forward w; +forward UPARROW; -forward w");
    # CL_KeyState: half the frame on the frame a key goes down, then all of it.
    assert controls.sample(0.016).move.y == 0.5;
    # cl_run is on: forward runs at the full speed.
    assert controls.sample(0.016).move.y == 1.0;
    run_config(shell, keyboard, controls, "cl_run 0");
    assert controls.sample(0.016).move.y == 0.5;
    run_config(shell, keyboard, controls, "+speed SHIFT");
    assert controls.sample(0.016).move.y == 1.0;
    run_config(shell, keyboard, controls, "-speed SHIFT; -forward UPARROW; +back s");
    assert controls.sample(0.016).move.y == -0.25;
    assert controls.sample(0.016).move.y == -0.5;
    run_config(shell, keyboard, controls, "-back");
    assert controls.sample(0.016).move.y == 0.0;
    # A press and release inside one frame still counts (CL_KeyState 0.25).
    run_config(shell, keyboard, controls, "cl_run 1; +moveright d; -moveright d");
    assert controls.sample(0.016).move.x > 0.0;
    assert controls.sample(0.016).move.x == 0.0;
    # Arrow keys turn at cl_yawspeed.
    run_config(shell, keyboard, controls, "+left LEFTARROW");
    controls.sample(0.5);
    turn = controls.sample(0.5);
    assert abs(turn.look_yaw - 0.5 * 140.0 * 0.017453292519943295) < 0.000001;
    run_config(shell, keyboard, controls, "-left LEFTARROW; +lookup PGDN");
    assert controls.sample(0.1).look_pitch > 0.0;
    run_config(shell, keyboard, controls, "-lookup PGDN");
}

test "one-shot commands ride in the next move only" {
    parts = fresh_input();
    shell = parts[0];
    keyboard = parts[1];
    controls = parts[2];
    run_config(shell, keyboard, controls, "impulse 4; invnext; centerview");
    first = controls.sample(0.016);
    assert first.weapon == 4 and first.next_item and first.center_view;
    second = controls.sample(0.016);
    assert second.weapon == 0 and not second.next_item and not second.center_view;
    run_config(shell, keyboard, controls, "impulse 10");
    assert controls.sample(0.016).weapon_step == 1;
    run_config(shell, keyboard, controls, "impulse 12; impulse 9");
    cheat = controls.sample(0.016);
    assert cheat.weapon_step == -1 and cheat.impulse == 9;
    run_config(shell, keyboard, controls, "weapon 7; weapprev");
    q3 = controls.sample(0.016);
    assert q3.weapon == 7 and q3.weapon_step == -1;
    run_config(shell, keyboard, controls, "+attack MOUSE1");
    shot = controls.sample(0.016);
    assert shot.fire;
    run_config(shell, keyboard, controls, "-attack MOUSE1; +moveup SPACE");
    jumped = controls.sample(0.016);
    assert not jumped.fire and jumped.jump and jumped.jump_held and jumped.move.z > 0.0;
    held = controls.sample(0.016);
    assert not held.jump and held.jump_held;
    run_config(shell, keyboard, controls, "-moveup SPACE; +button2 ENTER");
    assert controls.sample(0.016).use_item;
    run_config(shell, keyboard, controls, "-button2 ENTER");
}

test "the console edits a line, runs it, remembers it and completes names" {
    shell = Shell();
    shell.boot();
    console = Console();
    console.declare(shell);
    console.toggle();
    assert console.active;
    console.type_text("ech`o hello");
    assert console.line == "echo hello";
    console.key(shell, "LEFTARROW", False, False);
    console.key(shell, "BACKSPACE", False, False);
    assert console.line == "echo helo" and console.cursor == 8;
    console.key(shell, "END", False, False);
    console.key(shell, "ENTER", False, False);
    assert shell.log.lines[-1] == "]echo helo" and console.line == "";
    assert shell.execute_text("") == [] and shell.log.lines[-1] == "helo";
    console.key(shell, "UPARROW", False, False);
    assert console.line == "echo helo";
    console.key(shell, "DOWNARROW", False, False);
    assert console.line == "";
    console.type_text("scr_con");
    console.key(shell, "TAB", False, False);
    assert console.line == "scr_conspeed ";
    console.line = "c";
    console.cursor = 1;
    console.key(shell, "TAB", False, False);
    assert "    clear" in shell.log.lines and "    cvarlist" in shell.log.lines;
    console.line = "set con_n";
    console.cursor = len(console.line);
    console.key(shell, "TAB", False, False);
    assert console.line == "set con_notifytime ";
    # Keys the console does not use run their bindings.
    assert not console.key(shell, "F4", False, False) and console.key(shell, "a", False, False);
    console.key(shell, "PGUP", False, False);
    assert console.scroll == 2;
    console.advance(0.1);
    assert console.frac > 0.0 and console.frac <= 0.5;
    console.advance(1.0);
    assert console.frac == 0.5;
    console.toggle();
    console.advance(1.0);
    assert console.frac == 0.0 and not console.shown();
}

test "console rows wrap at the width and hide Q3 colour codes" {
    assert console_rows(["abcdefgh", ""], 3) == ["abc", "def", "gh", ""];
    assert console_visible("^1red^7 white") == "red white";
    assert console_rows(["^1abcd"], 2) == ["^1ab", "cd"];
}

test "the controls menu lists each game's actions, then the engine's" {
    q1 = control_actions("q1");
    assert q1[0] == ("+attack", "attack") and q1[1] == ("impulse 10", "change weapon");
    assert control_actions("q2")[-7] == ("cmd help", "help computer");
    assert ("weapon 9", "BFG") in control_actions("q3");
    assert control_actions("passion")[0] == ("+attack", "attack");
    assert ("toggleconsole", "console") in q1;
    assert binding_layer("passion", False).startswith("unbindall");
}

test "preferences keep the archived cvars and each game's bindings as scripts" {
    folder = os.path.join(os.getenv("TMPDIR", "/tmp"), "qp_preferences_test_" + str(os.getpid()));
    if not os.path.exists(folder) {
        os.makedirs(folder);
    }
    preferences = Preferences(home=folder);
    assert preferences.settings_text() == "" and not preferences.current();
    preferences.save(["seta fov \"100\"", "seta volume \"0.5\""]);
    assert preferences.current();
    parts = fresh_input();
    shell = parts[0];
    run_config(shell, parts[1], parts[2], preferences.settings_text());
    made = shell.cvar("fov");
    assert made is not None and made.number == 100.0;
    preferences.save_bindings("q2", ["unbindall", "bind TAB \"inven\""]);
    assert "bind TAB \"inven\"" in preferences.bindings_text("q2");
    assert preferences.bindings_text("q1") == "";
    preferences.forget_bindings("q2");
    assert preferences.bindings_text("q2") == "";
    os.remove(preferences.path());
    os.rmdir(folder);
    migrated = legacy_settings("QUAKEPASSION SETTINGS 3\n72 0.0022 1 300 60 0 1 0.25 1 2\n");
    assert "seta fov 88.2" in migrated and "seta sensitivity 5.73" in migrated;
    assert "seta m_pitch -0.022" in migrated and "seta qp_flyspeed 300" in migrated;
    assert "seta host_maxfps 60" in migrated and "seta r_novis 1" in migrated;
    assert "seta qp_god 1" in migrated and "seta skill 2" in migrated;
}
