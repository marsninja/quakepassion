"""More of the toolkit's controls: a field that offers a list of choices and
narrows it to what is typed, and a box for a passage of several lines."""

import from .canvas { Canvas, Rect }
import from .widget { Widget, Stage, UiEvent }
import from .widgets { TextField, draw_glyph }
import from .passage { row_starts, row_of, row_span, row_line, passage_line, passage_of, combo_matches, list_first }
import from engine.console.shell { quote_command_word }

"""The list a combo holds open under itself. Clicking a row asks for
`command` followed by that row."""
node ComboList(Widget) {
    has rows: list[str] = [],
        lit: int = -1,
        first: int = 0,
        command: str = "";

    def row_high -> int {
        return 22;
    }

    """How many rows show at once."""
    def most -> int {
        return 8;
    }

    """Sit under a field, or over it where the window leaves no room below."""
    def fit(stage: Stage, field: Rect) {
        tall = min(len(self.rows), self.most()) * self.row_high() + 4;
        top = field.bottom();
        if top + tall > stage.height and field.y - tall >= 0 {
            top = field.y - tall;
        }
        self.area = Rect(x=field.x, y=top, w=max(field.w, 120), h=tall);
        self.first = list_first(self.first, self.lit, self.most(), len(self.rows));
    }

    def row_at(y: int) -> int {
        row = self.first + (y - self.area.y - 2) // self.row_high();
        return row if y >= self.area.y + 2 and row < len(self.rows) else -1;
    }

    """Light the row `count` rows on, stopping at the ends."""
    def step(count: int) {
        if len(self.rows) == 0 {
            return;
        }
        self.lit = max(0, min(len(self.rows) - 1, self.lit + count));
        self.first = list_first(self.first, self.lit, self.most(), len(self.rows));
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.raised);
        canvas.outline(self.area, theme.border);
        last = min(len(self.rows), self.first + self.most());
        for row in range(self.first, last) {
            line = Rect(
                x=self.area.x + 1,
                y=self.area.y + 2 + (row - self.first) * self.row_high(),
                w=self.area.w - 2,
                h=self.row_high()
            );
            if row == self.lit {
                canvas.fill(line, theme.accent);
            }
            canvas.label(self.rows[row], line, theme.on_accent if row == self.lit else theme.text, -1, 6);
        }
        if len(self.rows) > self.most() {
            # How far down the list this window of it is.
            run = self.area.h - 4;
            bar = max(8, (run * self.most()) // len(self.rows));
            at = self.area.y + 2 + ((run - bar) * self.first) // max(1, len(self.rows) - self.most());
            canvas.fill(Rect(x=self.area.right() - 4, y=at, w=3, h=bar), theme.dim);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" and event.button == 0 {
            row = self.row_at(event.y);
            if row >= 0 {
                stage.close(self);
                stage.emit(self.command + " " + quote_command_word(self.rows[row]));
            }
            return True;
        }
        if event.kind == "wheel" {
            turned = -1 if event.wheel > 0.0 else 1;
            self.first = max(0, min(max(0, len(self.rows) - self.most()), self.first + turned));
            return True;
        }
        return True;
    }

    """Called every frame while open: a pointer that moves lights the row
    it is over."""
    def track(stage: Stage) {
        moved = stage.input.dx != 0 or stage.input.dy != 0;
        if moved and self.area.holds(stage.input.x, stage.input.y) {
            row = self.row_at(stage.input.y);
            if row >= 0 {
                self.lit = row;
            }
        }
    }

    def solid -> bool {
        return True;
    }
}

"""A field that offers `choices` in a list under itself. Typing narrows the
list to what matches; the arrows walk it and Enter takes the lit row. What
is typed need not be a choice: Enter with no row lit asks for it as it
stands, like a plain field."""
node Combo(TextField) {
    has choices: list[str] = [],
        chooser: ComboList | None = None,
        # Whether the words have changed since the field took the keyboard:
        # until they do the whole list is offered.
        typed: bool = False;

    """The list, while it is open."""
    def listed(stage: Stage) -> ComboList | None {
        held = self.chooser;
        if held is not None and held in stage.layers() {
            return held;
        }
        return None;
    }

    def shut(stage: Stage) {
        held = self.listed(stage);
        if held is not None {
            stage.close(held);
        }
        self.chooser = None;
    }

    """Open the list on what matches, or shut it when nothing does."""
    def list_choices(stage: Stage) {
        rows = combo_matches(self.draft if self.typed else "", self.choices);
        if len(rows) == 0 or not self.command {
            self.shut(stage);
            return;
        }
        held = self.listed(stage);
        if held is None {
            made = ComboList(transient=True, rows=rows, command=self.command);
            stage.open(made);
            self.chooser = made;
            made.fit(stage, self.area);
            return;
        }
        held.rows = rows;
        held.lit = -1;
        held.first = 0;
        held.fit(stage, self.area);
    }

    def draw(canvas: Canvas) {
        super.draw(canvas);
        theme = canvas.theme;
        mark = Rect(x=self.area.right() - 17, y=self.area.y + 1, w=16, h=self.area.h - 2);
        canvas.fill(mark, theme.field);
        draw_glyph(canvas, "down", mark.x + 4, self.area.y + (self.area.h - 8) // 2, 8, theme.dim);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        if kind == "focus" {
            self.typed = False;
            taken = super.on(event, stage);
            self.list_choices(stage);
            return taken;
        }
        if kind == "blur" {
            held = self.listed(stage);
            if held is not None and stage.input.pressed[0] and held.area.holds(stage.input.x, stage.input.y) {
                # The press is on the list, which asks for its own row: what
                # was typed to find it is let go.
                self.editing = False;
                self.draft = self.value;
                self.scroll = 0;
                return True;
            }
            self.shut(stage);
            return super.on(event, stage);
        }
        if kind == "press" {
            taken = super.on(event, stage);
            if self.listed(stage) is None {
                self.list_choices(stage);
            }
            return taken;
        }
        if kind == "text" {
            taken = super.on(event, stage);
            self.typed = True;
            self.list_choices(stage);
            return taken;
        }
        return super.on(event, stage);
    }

    def key(event: UiEvent, stage: Stage) -> bool {
        pressed = event.key;
        held = self.listed(stage);
        if pressed == "DOWNARROW" or pressed == "UPARROW" {
            if held is None {
                self.list_choices(stage);
            } else {
                held.step(1 if pressed == "DOWNARROW" else -1);
            }
            return True;
        }
        if (pressed == "ENTER" or pressed == "KP_ENTER") and held is not None and held.lit >= 0 {
            self.draft = held.rows[held.lit];
            self.cursor = len(self.draft);
            self.anchor = self.cursor;
        }
        if pressed == "ESCAPE" and held is not None {
            # The first Escape puts the list away; the next leaves the field.
            self.shut(stage);
            return True;
        }
        before = self.draft;
        taken = super.key(event, stage);
        if self.focused and self.draft != before {
            self.typed = True;
            self.list_choices(stage);
        }
        return taken;
    }
}

"""A box for a passage of several lines, wrapped to its width. Enter begins
a new line; Ctrl+Enter, Tab or a press elsewhere asks for `command` followed
by the passage as one line, its line breaks written as a backslash and an n
(the way a map's field holds them). Escape gives the change up. With
`numbered` every line has its number beside it."""
node TextArea(Widget) {
    has value: str = "",
        draft: str = "",
        command: str = "",
        ghost: str = "",
        # How many rows tall it asks to be.
        rows: int = 3,
        numbered: bool = False,
        # Whether a new line begins as far in as the line it was begun from.
        indents: bool = False,
        cursor: int = 0,
        anchor: int = 0,
        # The first row on show.
        top: int = 0,
        editing: bool = False,
        # Where each row begins, and the words and width that was worked
        # out for.
        starts: list[int] = [0],
        laid: str = "",
        laid_room: int = -1,
        # How far across the cursor keeps to while it goes up and down.
        aim: int = -1;

    def asks -> str {
        return self.command;
    }

    """Show `text` as the committed value (no command is asked for)."""
    def show(text: str) {
        self.value = text;
        if not self.editing {
            self.draft = passage_of(text);
        }
    }

    def line_high(canvas: Canvas) -> int {
        return canvas.theme.font + 4;
    }

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 120 if across else max(1, self.rows) * self.line_high(canvas) + 6;
    }

    def text_now -> str {
        return self.draft if self.editing else passage_of(self.value);
    }

    """How much of its left the line numbers take."""
    def gutter(canvas: Canvas) -> int {
        return canvas.text_width("0000", canvas.theme.small) + 8 if self.numbered else 0;
    }

    """Where the words begin, across the screen."""
    def words_left(canvas: Canvas) -> int {
        return self.area.x + 5 + self.gutter(canvas);
    }

    """How many rows show at once."""
    def rows_seen(canvas: Canvas) -> int {
        return max(1, (self.area.h - 6) // self.line_high(canvas));
    }

    """Break the words into rows for the width there is. Answers the words."""
    def lay(canvas: Canvas) -> str {
        text = self.text_now();
        room = max(8, self.area.w - 16 - self.gutter(canvas));
        if text == self.laid and room == self.laid_room {
            return text;
        }
        known: dict[str, int] = {};
        widths: list[int] = [];
        for letter in text {
            if letter not in known {
                # Twice less once: how far one more of it moves the next on.
                known[letter] = canvas.text_width(letter + letter) - canvas.text_width(letter);
            }
            widths.append(known[letter]);
        }
        self.starts = row_starts(text, widths, room);
        self.laid = text;
        self.laid_room = room;
        return text;
    }

    """The place in `row` nearest a distance across it."""
    def place_across(canvas: Canvas, text: str, row: int, across: int) -> int {
        span = row_span(text, self.starts, row);
        best = span[0];
        gap = abs(across);
        for i in range(span[0] + 1, span[1] + 1) {
            off = abs(canvas.text_width(text[span[0]:i]) - across);
            if off < gap {
                gap = off;
                best = i;
            }
        }
        return best;
    }

    """The place in the passage nearest a point on the screen."""
    def place_at(canvas: Canvas, x: int, y: int) -> int {
        text = self.lay(canvas);
        row = self.top + (y - self.area.y - 3) // self.line_high(canvas);
        row = max(0, min(len(self.starts) - 1, row));
        return self.place_across(canvas, text, row, x - self.words_left(canvas));
    }

    """Keep the cursor's row on show."""
    def follow(canvas: Canvas) {
        self.lay(canvas);
        self.top = list_first(self.top, row_of(self.starts, self.cursor), self.rows_seen(canvas), len(self.starts));
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.field);
        canvas.outline(self.area, theme.accent if self.focused else (theme.dim if self.hovered else theme.border));
        margin = self.gutter(canvas);
        inner = Rect(x=self.area.x + 5 + margin, y=self.area.y + 3, w=self.area.w - 10 - margin, h=self.area.h - 6);
        text = self.lay(canvas);
        high = self.line_high(canvas);
        if margin > 0 {
            # The numbers of the lines, each beside the row that begins it.
            canvas.clip(self.area.within(self.clip));
            canvas.fill(Rect(x=self.area.x + 1, y=self.area.y + 1, w=margin, h=self.area.h - 2), theme.panel);
            for row in range(self.top, len(self.starts)) {
                y = inner.y + (row - self.top) * high;
                if y >= inner.bottom() {
                    break;
                }
                number = row_line(text, self.starts, row);
                if number > 0 {
                    canvas.label(
                        str(number), Rect(x=self.area.x + 1, y=y, w=margin - 4, h=high), theme.faint, 1, 0, theme.small
                    );
                }
            }
        }
        canvas.clip(inner.within(self.clip));
        if not text and not self.focused {
            canvas.label(self.ghost, Rect(x=inner.x, y=inner.y, w=inner.w, h=high), theme.faint);
        }
        low = min(self.cursor, self.anchor);
        far = max(self.cursor, self.anchor);
        cursor_row = row_of(self.starts, self.cursor);
        for row in range(self.top, len(self.starts)) {
            y = inner.y + (row - self.top) * high;
            if y >= inner.bottom() {
                break;
            }
            span = row_span(text, self.starts, row);
            if self.focused and far > low and low <= span[1] and far > span[0] {
                x0 = inner.x + canvas.text_width(text[span[0]:max(low, span[0])]);
                x1 = inner.x + canvas.text_width(text[span[0]:min(far, span[1])]);
                if far > span[1] {
                    # The selection runs on past this row's end.
                    x1 += 5;
                }
                canvas.fill(Rect(x=x0, y=y, w=x1 - x0, h=high), theme.select);
            }
            canvas.text(text[span[0]:span[1]], inner.x, y + 2, theme.text if self.enabled else theme.faint);
            if self.focused and row == cursor_row and int(canvas.clock * 2.0) % 2 == 0 {
                x = inner.x + canvas.text_width(text[span[0]:self.cursor]);
                canvas.fill(Rect(x=x, y=y + 1, w=1, h=theme.font + 3), theme.text);
            }
        }
        seen = self.rows_seen(canvas);
        if len(self.starts) > seen {
            # How far down the passage this window of it is.
            bar = max(8, (inner.h * seen) // len(self.starts));
            at = inner.y + ((inner.h - bar) * self.top) // max(1, len(self.starts) - seen);
            canvas.fill(Rect(x=self.area.right() - 4, y=at, w=3, h=bar), theme.dim);
        }
        canvas.clip(self.clip);
    }

    def commit(stage: Stage) {
        if not self.editing {
            return;
        }
        self.editing = False;
        line = passage_line(self.draft);
        changed = line != self.value;
        self.value = line;
        self.top = 0;
        if changed and self.command {
            stage.emit(self.command + " " + quote_command_word(line));
        }
    }

    def replace_selection(text: str) {
        low = min(self.cursor, self.anchor);
        far = max(self.cursor, self.anchor);
        self.draft = self.draft[:low] + text + self.draft[far:];
        self.cursor = low + len(text);
        self.anchor = self.cursor;
        self.aim = -1;
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        if kind == "focus" {
            self.editing = True;
            self.draft = passage_of(self.value);
            self.cursor = len(self.draft);
            self.anchor = self.cursor;
            self.aim = -1;
            return True;
        }
        if kind == "blur" {
            self.commit(stage);
            return True;
        }
        if kind == "press" {
            self.cursor = self.place_at(stage.canvas, event.x, event.y);
            if not event.shift {
                self.anchor = self.cursor;
            }
            self.aim = -1;
            return True;
        }
        if kind == "double" {
            self.anchor = 0;
            self.cursor = len(self.draft);
            return True;
        }
        if kind == "drag" {
            self.cursor = self.place_at(stage.canvas, event.x, event.y);
            self.follow(stage.canvas);
            return True;
        }
        if kind == "wheel" {
            self.lay(stage.canvas);
            turned = -1 if event.wheel > 0.0 else 1;
            self.top = max(0, min(max(0, len(self.starts) - self.rows_seen(stage.canvas)), self.top + turned));
            return True;
        }
        if kind == "text" {
            self.replace_selection(event.text);
            self.follow(stage.canvas);
            return True;
        }
        if kind == "key" {
            return self.key(event, stage);
        }
        return kind in ["release", "click"];
    }

    """Move the cursor a row up or down, keeping how far across it is."""
    def climb(canvas: Canvas, down: bool) {
        text = self.lay(canvas);
        row = row_of(self.starts, self.cursor);
        if self.aim < 0 {
            self.aim = canvas.text_width(text[self.starts[row]:self.cursor]);
        }
        goal = row + (1 if down else -1);
        if goal < 0 {
            self.cursor = 0;
        } elif goal >= len(self.starts) {
            self.cursor = len(text);
        } else {
            self.cursor = self.place_across(canvas, text, goal, self.aim);
        }
    }

    def key(event: UiEvent, stage: Stage) -> bool {
        pressed = event.key;
        canvas = stage.canvas;
        if pressed == "ENTER" or pressed == "KP_ENTER" {
            if event.ctrl {
                stage.focus_on(None);
                return True;
            }
            lead = "";
            if self.indents {
                low = min(self.cursor, self.anchor);
                begun = self.draft.rfind("\n", 0, low) + 1;
                reach = begun;
                while reach < low and self.draft[reach] == " " {
                    reach += 1;
                }
                lead = self.draft[begun:reach];
            }
            self.replace_selection("\n" + lead);
            self.follow(canvas);
            return True;
        }
        if pressed == "ESCAPE" {
            self.draft = passage_of(self.value);
            self.editing = False;
            self.top = 0;
            stage.focus_on(None);
            return True;
        }
        if pressed == "TAB" {
            stage.focus_on(None);
            return False;
        }
        if event.ctrl and pressed == "a" {
            self.anchor = 0;
            self.cursor = len(self.draft);
            return True;
        }
        if event.ctrl and (pressed == "c" or pressed == "x") {
            low = min(self.cursor, self.anchor);
            far = max(self.cursor, self.anchor);
            if far > low {
                canvas.copy(self.draft[low:far]);
                if pressed == "x" {
                    self.replace_selection("");
                    self.follow(canvas);
                }
            }
            return True;
        }
        if event.ctrl and pressed == "v" {
            self.replace_selection(canvas.copied().replace("\r", ""));
            self.follow(canvas);
            return True;
        }
        if event.ctrl {
            # Other chords belong to the studio.
            return False;
        }
        if pressed == "BACKSPACE" or pressed == "DEL" {
            if self.cursor == self.anchor {
                if pressed == "BACKSPACE" and self.cursor > 0 {
                    self.anchor = self.cursor - 1;
                } elif pressed == "DEL" and self.cursor < len(self.draft) {
                    self.anchor = self.cursor + 1;
                }
            }
            self.replace_selection("");
            self.follow(canvas);
            return True;
        }
        if pressed == "PGUP" or pressed == "PGDN" {
            for turn in range(self.rows_seen(canvas)) {
                self.climb(canvas, pressed == "PGDN");
            }
            if not event.shift {
                self.anchor = self.cursor;
            }
            self.follow(canvas);
            return True;
        }
        if pressed == "UPARROW" or pressed == "DOWNARROW" {
            self.climb(canvas, pressed == "DOWNARROW");
            if not event.shift {
                self.anchor = self.cursor;
            }
            self.follow(canvas);
            return True;
        }
        moved = True;
        text = self.lay(canvas);
        row = row_of(self.starts, self.cursor);
        span = row_span(text, self.starts, row);
        if pressed == "LEFTARROW" {
            self.cursor = max(0, self.cursor - 1);
        } elif pressed == "RIGHTARROW" {
            self.cursor = min(len(self.draft), self.cursor + 1);
        } elif pressed == "HOME" {
            self.cursor = span[0];
        } elif pressed == "END" {
            # A row the words ran over the end of ends before its last
            # space, so that the cursor stays on it.
            wrapped = span[1] < len(text) and text[span[1]] != "\n";
            self.cursor = max(span[0], span[1] - 1) if wrapped else span[1];
        } else {
            moved = False;
        }
        if moved {
            self.aim = -1;
            if not event.shift {
                self.anchor = self.cursor;
            }
            self.follow(canvas);
            return True;
        }
        # Typed characters arrive as text; their key events stop here so they
        # are not taken for shortcuts.
        return len(pressed) == 1 or pressed == "SPACE";
    }

    def solid -> bool {
        return True;
    }

    def focusable -> bool {
        return self.enabled;
    }
}

"""A bar at the top of a panel that docks it where it is dragged: let go
near the window's left or right edge, the panel docks on that side; let go
in between, it floats there. It asks for `ed_dock <panel> at <x> <y>`
with where it was let go, and while it is dragged says where the pointer is
for the one who shows where it will land."""
node DockGrip(Widget) {
    has panel: str = "",
        text: str = "",
        # As tall as a panel's header, standing in for it.
        heading: bool = False,
        dragging: bool = False,
        at_x: int = 0,
        at_y: int = 0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if across {
            return canvas.text_width(self.text, canvas.theme.small) + 24;
        }
        return canvas.theme.row + 2 if self.heading else 16;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.accent.faded(120) if self.dragging else (theme.header if not self.hovered else theme.window));
        if self.heading {
            canvas.line(self.area.x, self.area.bottom() - 1, self.area.right(), self.area.bottom() - 1, theme.border);
        }
        # Three rows of dots: a thing to take hold of.
        for row in range(3) {
            for dot in range(3) {
                canvas.fill(Rect(x=self.area.x + 5 + dot * 3, y=self.area.y + 4 + row * 3, w=1, h=1), theme.dim);
            }
        }
        canvas.label(
            self.text.upper() if self.heading else self.text, Rect(x=self.area.x + 16, y=self.area.y, w=max(0, self.area.w - 16), h=self.area.h),
            theme.dim if self.heading else theme.faint, -1, 2, theme.small
        );
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.dragging = False;
            self.at_x = event.x;
            self.at_y = event.y;
            return True;
        }
        if event.kind == "drag" {
            self.dragging = True;
            self.at_x = event.x;
            self.at_y = event.y;
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            if self.dragging {
                stage.emit("ed_dock " + self.panel + " at " + str(event.x) + " " + str(event.y));
            }
            self.dragging = False;
            return True;
        }
        return event.kind in ["click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""Where a panel let go at `x` of a window `width` wide docks: on the left
or the right within a fifth of the window's width of that edge, else it
floats."""
def dock_place(x: int, width: int) -> str {
    margin = max(40, width // 5);
    if x <= margin {
        return "left";
    }
    if x >= width - margin {
        return "right";
    }
    return "float";
}
