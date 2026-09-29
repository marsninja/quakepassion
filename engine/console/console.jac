"""The drop-down console (console.c, keys.c Key_Console, cl_console.c).

It slides down over the top half of the view at scr_conspeed, drawn in each
game's own style: Quake's gfx/conback.lmp and Quake II's pics/conback.pcx
sliding down with the conchars text (Con_DrawConsole), Quake III's scrolling
"console" shader with its red rule and the bigchars sheet drawn as small
characters (Con_DrawSolidConsole). Without the game's art it falls back to a
plain panel. Typing edits one line with a cursor; Enter runs it, Tab completes
command and cvar names (listing them when several match, as Q3), Up and Down
walk the last 32 lines, PgUp, PgDn and the wheel scroll back."""
import from vendor.raylib {
    def GetTime -> f64;  def BeginBlendMode(mode: i32) -> None;  def EndBlendMode -> None;  def GetClipboardText -> str;
}
import from ..render.renderer { Color, DrawRectangle, DrawText }
import from ..render.hud { HudRenderer }
import from .cvar { Cvar, CVAR_ARCHIVE }
import from .shell { Shell, ConsoleLog }

"""Q3's g_color_table for ^0 to ^7."""
glob CONSOLE_COLORS: list[list[int]] = [
    [0, 0, 0, 255],
    [255, 0, 0, 255],
    [0, 255, 0, 255],
    [255, 255, 0, 255],
    [0, 0, 255, 255],
    [0, 255, 255, 255],
    [255, 0, 255, 255],
    [255, 255, 255, 255]
];

obj ConsoleCvars {
    has speed: Cvar = Cvar(
            name="scr_conspeed",
            reset_text="3",
            kind="float",
            low=0.1,
            high=100.0,
            aliases=["con_conspeed"],
            flags=CVAR_ARCHIVE,
            description="console drop speed, screens per second"
        ),
        notify_time: Cvar = Cvar(
            name="con_notifytime",
            reset_text="3",
            kind="float",
            low=0.0,
            high=60.0,
            flags=CVAR_ARCHIVE,
            description="seconds printed lines stay at the top of the view"
        );
}

obj Console {
    has cvars: ConsoleCvars = ConsoleCvars(),
        active: bool = False,
        frac: float = 0.0,
        line: str = "",
        cursor: int = 0,
        history: list[str] = [],
        history_line: int = 0,
        scroll: int = 0,
        columns: int = 78;

    def declare(shell: Shell) {
        self.cvars.speed = shell.register(self.cvars.speed);
        self.cvars.notify_time = shell.register(self.cvars.notify_time);
    }

    """Con_ToggleConsole_f: drop the console or put it away, clearing the typed
    line (Key_ClearTyping)."""
    def toggle {
        self.active = not self.active;
        self.line = "";
        self.cursor = 0;
        self.scroll = 0;
        self.history_line = len(self.history);
    }

    """SCR_RunConsole: slide toward half the screen (open) or away."""
    def advance(dt: float) {
        target = 0.5 if self.active else 0.0;
        step = self.cvars.speed.number * max(0.0, dt);
        if self.frac < target {
            self.frac = min(target, self.frac + step);
        } elif self.frac > target {
            self.frac = max(target, self.frac - step);
        }
    }

    def shown -> bool {
        return self.frac > 0.0;
    }

    """Key_Console: a key pressed while the console is down. Returns whether
    the console used it (keys it does not use run their bindings)."""
    def key(shell: Shell, name: str, ctrl: bool, shift: bool) -> bool {
        if name == "ENTER" or name == "KP_ENTER" {
            self.submit(shell);
        } elif name == "TAB" {
            self.complete(shell);
        } elif name == "BACKSPACE" {
            if self.cursor > 0 {
                self.line = self.line[:self.cursor - 1] + self.line[self.cursor:];
                self.cursor -= 1;
            }
        } elif name == "DEL" or name == "KP_DEL" {
            self.line = self.line[:self.cursor] + self.line[self.cursor + 1:];
        } elif name == "LEFTARROW" or name == "KP_LEFTARROW" {
            self.cursor = max(0, self.cursor - 1);
        } elif name == "RIGHTARROW" or name == "KP_RIGHTARROW" {
            self.cursor = min(len(self.line), self.cursor + 1);
        } elif (name == "HOME" or name == "KP_HOME") and ctrl {
            self.scroll = len(shell.log.lines);
        } elif (name == "END" or name == "KP_END") and ctrl {
            self.scroll = 0;
        } elif name == "HOME" or name == "KP_HOME" {
            self.cursor = 0;
        } elif name == "END" or name == "KP_END" {
            self.cursor = len(self.line);
        } elif name == "UPARROW" or name == "KP_UPARROW" {
            if self.history_line > 0 {
                self.history_line -= 1;
                self.line = self.history[self.history_line];
                self.cursor = len(self.line);
            }
        } elif name == "DOWNARROW" or name == "KP_DOWNARROW" {
            if self.history_line < len(self.history) {
                self.history_line += 1;
                self.line = self.history[self.history_line] if self.history_line < len(self.history) else "";
                self.cursor = len(self.line);
            }
        } elif name == "PGUP" or name == "KP_PGUP" or name == "MWHEELUP" {
            self.scroll += 2;
        } elif name == "PGDN" or name == "KP_PGDN" or name == "MWHEELDOWN" {
            self.scroll = max(0, self.scroll - 2);
        } elif name == "l" and ctrl {
            # Q3 Console_Key: ctrl-L clears the console text.
            shell.builtin(["clear"]);
        } elif (name == "v" and ctrl) or ((name == "INS" or name == "KP_INS") and shift) {
            self.type_text(str(GetClipboardText()));
        } else {
            return len(name) == 1 or name in ["SPACE", "SHIFT", "CTRL", "ALT", "COMMAND", "CAPSLOCK"];
        }
        return True;
    }

    """Printable characters typed this frame. The console key's own
    characters open and close it and are not typed (consolekeys['`'])."""
    def type_text(text: str) {
        for c in text {
            if c == "`" or c == "~" or ord(c) < 32 or ord(c) > 126 {
                continue;
            }
            if len(self.line) >= 255 {
                break;
            }
            self.line = self.line[:self.cursor] + c + self.line[self.cursor:];
            self.cursor += 1;
        }
    }

    """Enter: print the line, remember it and run it."""
    def submit(shell: Shell) {
        text = self.line;
        shell.print("]" + text);
        # Q3 lets console lines start with a slash or backslash.
        if text.startswith("/") or text.startswith("\\") {
            text = text[1:];
        }
        if text.strip() {
            shell.add_text(text);
            if not self.history or self.history[-1] != self.line {
                self.history.append(self.line);
            }
            while len(self.history) > 32 {
                self.history.pop(0);
            }
        }
        self.history_line = len(self.history);
        self.line = "";
        self.cursor = 0;
        self.scroll = 0;
    }

    """Tab (Q3 Field_CompleteCommand): complete the command or cvar name being
    typed (or the cvar after set, seta, reset, toggle and vstr); several
    matches are listed and the line grows to what they share."""
    def complete(shell: Shell) {
        text = self.line;
        slash = "";
        if text.startswith("/") or text.startswith("\\") {
            slash = text[0];
            text = text[1:];
        }
        lead = "";
        word = text;
        if " " in text {
            head = text.split(" ", 1)[0];
            if head.lower() not in ["set", "seta", "reset", "toggle", "vstr"] or " " in text.split(" ", 1)[1] {
                return;
            }
            lead = head + " ";
            word = text.split(" ", 1)[1];
        }
        matches = shell.completions(word);
        if lead {
            matches = [name for name in matches if shell.cvar(name) is not None];
        }
        if not matches {
            return;
        }
        if len(matches) == 1 {
            self.line = slash + lead + matches[0] + " ";
        } else {
            shell.print("]" + self.line);
            for name in matches {
                shell.print("    " + name);
            }
            shared = matches[0];
            for name in matches[1:] {
                n = 0;
                while n < len(shared) and n < len(name) and shared[n].lower() == name[n].lower() {
                    n += 1;
                }
                shared = shared[:n];
            }
            if len(shared) > len(word) {
                self.line = slash + lead + shared;
            }
        }
        self.cursor = len(self.line);
    }

    """Draw the console `frac` of the way down a `width` by `height` screen, in
    the style of `game` when its art is loaded."""
    def draw(hud: HudRenderer, log: ConsoleLog, game: str, width: int, height: int) {
        lines = int(float(height) * self.frac);
        if lines <= 0 {
            return;
        }
        now = float(GetTime());
        styled = hud.has_pic("conchars") and game in ["q1", "q2", "q3"];
        if not styled {
            self.draw_plain(log, width, lines);
            return;
        }
        big = game == "q3";
        # The text keeps about 80 columns: 8-pixel cells scaled by the width
        # (Q3's small characters are twice as tall).
        scale = float(max(1, width // 640));
        cw = 8.0 * scale;
        ch = cw * (2.0 if big else 1.0);
        white = [255, 255, 255, 255];
        if big {
            # Con_DrawSolidConsole: the scrolling console shader, a red rule.
            rule = 2.0 * float(height) / 480.0;
            y = float(lines) - rule;
            if y >= 1.0 {
                # Stage 1 replaces what is below (blendFunc GL_ONE GL_ZERO:
                # added onto black), stage 2 adds (blendFunc add); both
                # scale 2 1 and scroll.
                drift = now * 0.02;
                DrawRectangle(0, 0, i32(width), i32(y), Color(r=0, g=0, b=0, a=255));
                hud.flush();
                BeginBlendMode(i32(3));
                hud.blit("conback", 0.0, 0.0, float(width), y, white, drift, 0.0, 2.0 + drift, 1.0);
                if hud.has_pic("conback2") {
                    hud.blit("conback2", 0.0, 0.0, float(width), y, white, now * 0.2, now * 0.1, 2.0 + now * 0.2, 1.0 + now * 0.1);
                }
                hud.flush();
                EndBlendMode();
            } else {
                y = 0.0;
            }
            DrawRectangle(0, i32(y), i32(width), i32(max(1.0, rule)), Color(r=255, g=0, b=0, a=255));
            hud.flush();
        } else {
            # Draw_ConsoleBackground: the whole picture slides down.
            hud.blit("conback", 0.0, float(lines - height), float(width), float(height));
        }
        self.columns = max(10, int(float(width) / cw) - 2);
        version = "QuakePassion";
        if big {
            hud.chars(version, float(width) - float(len(version)) * cw, float(lines) - ch * 1.5, cw, CONSOLE_COLORS[1], tall=ch);
        } elif game == "q2" {
            hud.chars(version, float(width) - float(len(version) + 1) * cw, float(lines) - 1.5 * cw, cw, white, high=128);
        } else {
            hud.chars(version, float(width) - float(len(version) + 1) * cw, float(lines) - 1.75 * cw, cw, white, high=128);
        }
        rows = console_rows(log.lines, self.columns);
        y = float(lines) - ch * 3.0;
        visible = int((float(lines) - ch * 2.0) / ch) - 1;
        self.scroll = max(0, min(self.scroll, len(rows) - 1));
        if self.scroll > 0 {
            marks = "";
            for x in range(0, self.columns, 4) {
                marks += "^   ";
            }
            hud.chars(marks[:self.columns], cw, y, cw, CONSOLE_COLORS[1] if big else white, tall=ch);
            y -= ch;
            visible -= 1;
        }
        index = len(rows) - 1 - self.scroll;
        while visible > 0 and index >= 0 and y > -ch {
            console_text(hud, rows[index], cw, y, cw, ch, big);
            y -= ch;
            index -= 1;
            visible -= 1;
        }
        # Con_DrawInput: "]" and the line, scrolled to keep the cursor shown.
        shown = self.line;
        start = max(0, self.cursor - (self.columns - 2));
        shown = shown[start:start + self.columns - 1];
        input_y = float(lines) - ch * 2.0;
        hud.chars("]" + shown, cw, input_y, cw, white, tall=ch);
        if int(now * 4.0) % 2 == 0 {
            cursor = chr(10) if big else chr(11);
            hud.chars("_" if big else cursor, cw * float(2 + self.cursor - start), input_y, cw, white, tall=ch);
        }
        hud.flush();
    }

    """The console without the game's art: a dark panel and the default font."""
    def draw_plain(log: ConsoleLog, width: int, lines: int) {
        DrawRectangle(0, 0, i32(width), i32(lines), Color(r=20, g=16, b=12, a=235));
        DrawRectangle(0, i32(lines - 2), i32(width), 2, Color(r=255, g=184, b=107, a=255));
        size = 20;
        self.columns = max(10, width // 11 - 2);
        rows = console_rows(log.lines, self.columns);
        y = lines - size * 3;
        index = len(rows) - 1 - self.scroll;
        while index >= 0 and y > -size {
            DrawText(rows[index], 12, i32(y), i32(size), Color(r=235, g=229, b=215, a=255));
            y -= size + 2;
            index -= 1;
        }
        cursor = "_" if int(float(GetTime()) * 4.0) % 2 == 0 else " ";
        DrawText(
            "]" + self.line[:self.cursor] + cursor + self.line[self.cursor:],
            12,
            i32(lines - size * 2 + 4),
            i32(size),
            Color(r=255, g=184, b=107, a=255)
        );
    }
}

"""The log's lines wrapped at `columns` (Con_Linefeed's line width)."""
def console_rows(lines: list[str], columns: int) -> list[str] {
    rows: list[str] = [];
    width = max(1, columns);
    for line in lines {
        text = line.replace("\t", "    ");
        if not text {
            rows.append("");
            continue;
        }
        while len(console_visible(text)) > width {
            cut = console_cut(text, width);
            rows.append(text[:cut]);
            text = text[cut:];
        }
        rows.append(text);
    }
    return rows;
}

"""Text without Q3 colour escapes (^0 to ^9)."""
def console_visible(text: str) -> str {
    shown = "";
    i = 0;
    while i < len(text) {
        if text[i] == "^" and i + 1 < len(text) and text[i + 1] >= "0" and text[i + 1] <= "9" {
            i += 2;
            continue;
        }
        shown += text[i];
        i += 1;
    }
    return shown;
}

"""Where to cut `text` so `columns` visible characters stay on the row."""
def:priv console_cut(text: str, columns: int) -> int {
    shown = 0;
    i = 0;
    while i < len(text) and shown < columns {
        if text[i] == "^" and i + 1 < len(text) and text[i + 1] >= "0" and text[i + 1] <= "9" {
            i += 2;
            continue;
        }
        shown += 1;
        i += 1;
    }
    return i;
}

"""A console row in the character sheet; Q3 rows change colour at ^N."""
def:priv console_text(hud: HudRenderer, text: str, x: float, y: float, cw: float, ch: float, big: bool) {
    if not big or "^" not in text {
        hud.chars(console_visible(text), x, y, cw, [255, 255, 255, 255], tall=ch);
        return;
    }
    tint = CONSOLE_COLORS[7];
    column = 0;
    i = 0;
    run = "";
    while i <= len(text) {
        escape = i + 1 < len(text) and text[i] == "^" and text[i + 1] >= "0" and text[i + 1] <= "9";
        if i == len(text) or escape {
            if run {
                hud.chars(run, x + float(column) * cw, y, cw, tint, tall=ch);
                column += len(run);
                run = "";
            }
            if i == len(text) {
                break;
            }
            tint = CONSOLE_COLORS[(ord(text[i + 1]) - 48) % 8];
            i += 2;
            continue;
        }
        run += text[i];
        i += 1;
    }
}
