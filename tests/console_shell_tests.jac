import from engine.console.cvar { Cvar, CVAR_ARCHIVE, CVAR_USER_CREATED, cvar_number, cvar_number_text }
import from engine.console.shell { Shell, command_tokens, command_line_end, name_matches, command_line_text }

test "command lines split on semicolons and newlines outside quotes and comments" {
    assert command_tokens("bind  TAB \"+showscores\"  // scores") == ["bind", "TAB", "+showscores"];
    assert command_tokens("bind / \"impulse 10\"") == ["bind", "/", "impulse 10"];
    assert command_tokens("  /* note */ echo hi") == ["echo", "hi"];
    assert command_tokens("\"unterminated word") == ["unterminated word"];
    assert command_line_end("echo \"a;b\"; echo c") == 10;
    assert command_line_end("echo a // x;y\necho b") == 13;
    assert name_matches("cl_*speed", "cl_forwardspeed") and not name_matches("cl_*speed", "sensitivity");
    assert name_matches("speed", "cl_sidespeed") and name_matches("", "anything");
}

test "cvars keep their kind: numbers parse as atof and clamp to their bounds" {
    assert cvar_number("3.5abc") == 3.5 and cvar_number("x") == 0.0 and cvar_number("-2") == -2.0;
    assert cvar_number_text(90.0) == "90" and cvar_number_text(0.25) == "0.25";
    fov = Cvar(name="fov", reset_text="90", kind="float", low=10.0, high=170.0);
    fov.assign("200");
    assert fov.number == 170.0 and fov.text == "170";
    fov.assign("95.5");
    assert fov.text == "95.5" and fov.integer == 95;
    flag = Cvar(name="r_novis", reset_text="0", kind="bool");
    flag.assign("7");
    assert flag.text == "1" and flag.on();
    whole = Cvar(name="skill", reset_text="1", kind="int", low=0.0, high=4.0);
    whole.assign("2.9");
    assert whole.integer == 2 and whole.text == "2";
}

test "the shell sets, shows, toggles and resets cvars and lists them" {
    shell = Shell();
    shell.boot();
    volume = shell.register(
        Cvar(name="volume", reset_text="0.7", kind="float", low=0.0, high=1.0, flags=CVAR_ARCHIVE, aliases=["s_volume"])
    );
    assert volume.number == 0.7;
    assert shell.execute_text("s_volume 0.5") == [];
    assert volume.number == 0.5;
    shell.execute_text("volume");
    assert shell.log.lines[-1] == "\"volume\" is:\"0.5\" default:\"0.7\"";
    shell.execute_text("set volume 3; toggle volume");
    assert volume.number == 0.0;
    shell.execute_text("reset s_volume");
    assert volume.text == "0.7";
    shell.execute_text("set my_var hello world; seta kept 2");
    made = shell.cvar("my_var");
    assert made is not None and made.text == "hello world" and made.flags & CVAR_USER_CREATED;
    assert shell.archive_lines() == ["seta kept \"2\"", "seta volume \"0.7\""];
    shell.execute_text("frobnicate");
    assert shell.log.lines[-1] == "Unknown command \"frobnicate\"";
    shell.execute_text("cvarlist vol");
    assert shell.log.lines[-1] == "1 total cvars";
    assert shell.completions("s_v") == ["s_volume"] and "set" in shell.completions("se");
}

test "a cvar set before its owner registers it keeps the set value" {
    shell = Shell();
    shell.boot();
    shell.execute_text("seta cg_fov 100");
    fov = shell.register(Cvar(name="fov", reset_text="90", kind="float", aliases=["cg_fov"]));
    assert fov.number == 100.0 and shell.cvar("cg_fov") is fov;
}

test "aliases, wait and forwarded commands run in buffer order" {
    shell = Shell();
    shell.boot();
    shell.command("map", "host", "map <name>");
    shell.execute_text("alias go \"echo one; map e1m1\"");
    forwarded = shell.execute_text("go");
    assert forwarded == [["map", "e1m1"]] and shell.log.lines[-1] == "one";
    shell.add_text("echo before; wait; echo after");
    assert shell.next_command() == ["echo", "before"];
    shell.run(["echo", "before"]);
    assert shell.next_command() == ["wait"];
    shell.run(["wait"]);
    assert shell.next_command() == [];
    assert shell.next_command() == ["echo", "after"];
    shell.execute_text("alias loop loop");
    shell.execute_text("loop");
    assert shell.log.lines[-1] == "ALIAS_LOOP_COUNT";
}

test "command line +commands run as console lines (stuffcmds)" {
    assert command_line_text(["+map", "e1m2", "+god"]) == "map e1m2\ngod";
    assert command_line_text(["ignored", "+echo", "two words"]) == "echo \"two words\"";
    assert command_line_text([]) == "";
}

test "a cvar holds its reset value before any shell registers it" {
    # Scripts that open a Renderer without a shell read these: an fov of 0
    # made every 3D view empty.
    fov = Cvar(name="fov", reset_text="90", kind="float", low=10.0, high=170.0);
    assert fov.number == 90.0 and fov.text == "90" and not fov.modified;
    width = Cvar(name="vid_width", reset_text="1280", kind="int");
    assert width.integer == 1280;
    typed = Cvar(name="made_up", text="7", flags=CVAR_USER_CREATED);
    assert typed.text == "7";
}
