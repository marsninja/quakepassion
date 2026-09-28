"""The user's configuration, independent of world snapshots: the engine-wide
archived cvars in one settings file and each game's key bindings beside it,
both written as console scripts the shell runs (Host_WriteConfiguration's
config.cfg), so a line typed at the console reads the same in the file.

The settings file began as a row of numbers (versions 1 to 3); such a file is
read as the cvars that replaced those settings."""
import os;
import math;
import from .savegame { read_save, write_save, values }

glob SETTINGS_HEADER: str = "// QUAKEPASSION SETTINGS 4";

obj Preferences {
    has home: str = "";

    """Where the files live: `home`, else QP_CONFIG_DIR, else HOME."""
    def folder -> str {
        if self.home {
            return self.home;
        }
        configured = os.getenv("QP_CONFIG_DIR", "");
        return configured if configured else os.getenv("HOME", ".");
    }

    def path -> str {
        return self.folder() + "/.quakepassion-settings.txt";
    }

    """A game's key bindings (the part of each game's config.cfg that stays
    with that game)."""
    def bindings_path(game: str) -> str {
        return self.folder() + "/.quakepassion-" + game + "-bindings.cfg";
    }

    def exists -> bool {
        return os.path.exists(self.path());
    }

    """Whether the settings file is the current, complete kind."""
    def current -> bool {
        if not self.exists() {
            return False;
        }
        return read_save(self.path()).startswith(SETTINGS_HEADER);
    }

    """The settings as console text: the file itself, or an earlier version's
    numbers as the cvars that replaced them ("" when there is no file)."""
    def settings_text -> str {
        if not self.exists() {
            return "";
        }
        text = read_save(self.path());
        if text.startswith(SETTINGS_HEADER) {
            return text;
        }
        return legacy_settings(text);
    }

    def bindings_text(game: str) -> str {
        path = self.bindings_path(game);
        return read_save(path) if os.path.exists(path) else "";
    }

    """Write the archived cvars (Cvar_WriteVariables' seta lines)."""
    def save(lines: list[str]) {
        write_save(
            self.path(),
            SETTINGS_HEADER
                + "\n// Engine-wide settings; each game's key bindings are in .quakepassion-<game>-bindings.cfg.\n"
                + "\n".join(lines)
                + "\n"
        );
    }

    """Drop a game's saved bindings, so its defaults apply again."""
    def forget_bindings(game: str) {
        path = self.bindings_path(game);
        if os.path.exists(path) {
            os.remove(path);
        }
    }

    """Write a game's bindings (Key_WriteBindings)."""
    def save_bindings(game: str, lines: list[str]) {
        write_save(
            self.bindings_path(game),
            "// QuakePassion " + game + " key bindings\n" + "\n".join(lines) + "\n"
        );
    }
}

"""Settings versions 1 to 3 (fov, sensitivity, invert, fly speed, frame
limit, culling, overlay, volume, then god mode and skill) as the cvars that
replaced them. The vertical field of view becomes fov's 4:3 horizontal angle
and radians per pixel become sensitivity at m_yaw 0.022, so the view and the
mouse feel as they did."""
def legacy_settings(text: str) -> str {
    data = text.splitlines();
    versions = ["QUAKEPASSION SETTINGS 1", "QUAKEPASSION SETTINGS 2", "QUAKEPASSION SETTINGS 3"];
    if len(data) != 2 or data[0] not in versions {
        raise ValueError("Invalid settings version");
    }
    row = values(data[1], 8 + versions.index(data[0]));
    vertical = max(40.0, min(110.0, row[0]));
    horizontal = math.degrees(2.0 * math.atan(math.tan(math.radians(vertical) * 0.5) / 0.75));
    sensitivity = max(0.00022, min(0.011, row[1])) / math.radians(0.022);
    lines = [
        "seta fov " + legacy_number(horizontal, 10.0),
        "seta sensitivity " + legacy_number(sensitivity, 100.0),
        "seta m_pitch " + ("-0.022" if row[2] != 0.0 else "0.022"),
        "seta qp_flyspeed " + legacy_number(max(60.0, min(1920.0, row[3])), 1.0),
        "seta host_maxfps " + str(max(0, min(1000, int(row[4])))),
        "seta r_novis " + ("0" if row[5] != 0.0 else "1"),
        "seta qp_overlay " + ("1" if row[6] != 0.0 else "0"),
        "seta volume " + legacy_number(max(0.0, min(1.0, row[7])), 100.0)
    ];
    if len(row) >= 9 {
        lines.append("seta qp_god " + ("1" if row[8] != 0.0 else "0"));
    }
    if len(row) >= 10 {
        lines.append("seta skill " + str(max(0, min(4, int(row[9])))));
    }
    return "\n".join(lines) + "\n";
}

"""`value` rounded to 1/`scale`, written without a trailing ".0"."""
def:priv legacy_number(value: float, scale: float) -> str {
    rounded = float(round(value * scale)) / scale;
    if rounded == float(int(rounded)) {
        return str(int(rounded));
    }
    return str(rounded);
}
