"""The studio's controls: boxes that lay their children out in a row or a
column, and the labels, buttons, fields, lists, menus and splitters inside
them. Each is a Widget node; see widget.jac for how they are laid out, drawn
and fed input."""
import from .canvas { Canvas, Rect, Ink }
import from .widget { Widget, Stage, UiEvent }
import from engine.console.shell { quote_command_word }

"""Children side by side (`across`) or stacked, each as long as it asks for;
the ones that `grow` share what is left."""
node Box(Widget) {
    has across: bool = False,
        pad: int = 0,
        gap: int = 0,
        # Theme colours by name: "" draws nothing.
        fill: str = "",
        rim: str = "";

    def lays_across -> bool {
        return self.across;
    }

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        total = 0;
        count = 0;
        for kid in self.kids() {
            if not kid.shown {
                continue;
            }
            length = kid.wanted(canvas, across);
            if across == self.across {
                total += length;
                count += 1;
            } else {
                total = max(total, length);
            }
        }
        if across == self.across and count > 1 {
            total += self.gap * (count - 1);
        }
        return total + 2 * self.pad;
    }

    def place(canvas: Canvas) {
        inner = self.area.inset(self.pad);
        shown = [kid for kid in self.kids() if kid.shown];
        if not shown {
            return;
        }
        room = (inner.w if self.across else inner.h) - self.gap * (len(shown) - 1);
        lengths: list[int] = [];
        fixed = 0;
        shares = 0;
        for kid in shown {
            length = 0 if kid.grow > 0 else kid.wanted(canvas, self.across);
            lengths.append(length);
            fixed += length;
            shares += kid.grow;
        }
        spare = max(0, room - fixed);
        handed = 0;
        last_growing = -1;
        for i in range(len(shown)) {
            if shown[i].grow > 0 {
                lengths[i] = (spare * shown[i].grow) // shares;
                handed += lengths[i];
                last_growing = i;
            }
        }
        if last_growing >= 0 {
            lengths[last_growing] += spare - handed;
        }
        at = inner.x if self.across else inner.y;
        for i in range(len(shown)) {
            if self.across {
                shown[i].area = Rect(x=at, y=inner.y, w=lengths[i], h=inner.h);
            } else {
                shown[i].area = Rect(x=inner.x, y=at, w=inner.w, h=lengths[i]);
            }
            at += lengths[i] + self.gap;
        }
    }

    def draw(canvas: Canvas) {
        if self.fill {
            canvas.fill(self.area, theme_ink(canvas, self.fill));
        }
        if self.rim {
            canvas.outline(self.area, theme_ink(canvas, self.rim));
        }
    }

    def solid -> bool {
        return bool(self.fill);
    }
}

"""A theme colour by name."""
def theme_ink(canvas: Canvas, name: str) -> Ink {
    theme = canvas.theme;
    if name == "panel" {
        return theme.panel;
    }
    if name == "raised" {
        return theme.raised;
    }
    if name == "header" {
        return theme.header;
    }
    if name == "border" {
        return theme.border;
    }
    if name == "field" {
        return theme.field;
    }
    if name == "dim" {
        return theme.dim;
    }
    if name == "faint" {
        return theme.faint;
    }
    if name == "accent" {
        return theme.accent;
    }
    if name == "warn" {
        return theme.warn;
    }
    if name == "good" {
        return theme.good;
    }
    if name == "window" {
        return theme.window;
    }
    return theme.text;
}

"""Empty room: a fixed gap, or a spring when it grows."""
node Spacer(Widget) {}

node Label(Widget) {
    has text: str = "",
        tone: str = "text",
        align: int = -1,
        pad: int = 0,
        small: bool = False;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        size = canvas.theme.small if self.small else 0;
        if across {
            return canvas.text_width(self.text, size) + 2 * self.pad;
        }
        return canvas.theme.row;
    }

    def draw(canvas: Canvas) {
        canvas.label(
            self.text,
            self.area,
            theme_ink(canvas, self.tone),
            self.align,
            self.pad,
            canvas.theme.small if self.small else 0
        );
    }
}

"""A panel's title strip."""
node Header(Label) {
    def wanted(canvas: Canvas, across: bool) -> int {
        if across {
            return canvas.text_width(self.text) + 2 * canvas.theme.pad;
        }
        return canvas.theme.row + 2;
    }

    def draw(canvas: Canvas) {
        canvas.fill(self.area, canvas.theme.header);
        canvas.label(self.text.upper(), self.area, canvas.theme.dim, -1, canvas.theme.pad, canvas.theme.small);
        canvas.line(
            self.area.x, self.area.bottom() - 1, self.area.right(), self.area.bottom() - 1, canvas.theme.border
        );
    }

    def solid -> bool {
        return True;
    }
}

"""A button that asks for a console command. `lit` draws it switched on, and
`bold` in the accent colour; `glyph` draws a play, pause, stop or step mark
before the text."""
node PushButton(Widget) {
    has text: str = "",
        command: str = "",
        glyph: str = "",
        lit: bool = False,
        bold: bool = False;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        if across {
            mark = canvas.theme.row - 6 if self.glyph else 0;
            words = canvas.text_width(self.text) if self.text else 0;
            return words + mark + 2 * canvas.theme.pad + 4 + (4 if self.glyph and self.text else 0);
        }
        return canvas.theme.row + 2;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        back = theme.raised;
        front = theme.text if self.enabled else theme.faint;
        if self.bold or self.lit {
            back = theme.accent;
            front = theme.on_accent;
        }
        if self.enabled and self.held and self.hovered {
            back = theme.press if not (self.bold or self.lit) else theme.accent.faded(200);
        } elif self.enabled and self.hovered and not (self.bold or self.lit) {
            back = theme.hover;
        }
        canvas.fill(self.area, back);
        canvas.outline(self.area, theme.border);
        at = self.area.x + theme.pad + 2;
        if self.glyph {
            side = theme.row - 10;
            draw_glyph(canvas, self.glyph, at, self.area.y + (self.area.h - side) // 2, side, front);
            at += side + 4;
        }
        if self.text {
            if self.glyph {
                canvas.label(
                    self.text, Rect(x=at, y=self.area.y, w=self.area.right() - at, h=self.area.h), front
                );
            } else {
                canvas.label(self.text, self.area, front, 0);
            }
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" and event.button == 0 {
            stage.emit(self.command);
            return True;
        }
        return event.kind in ["press", "release", "double", "drag"];
    }

    def solid -> bool {
        return True;
    }
}

"""A small mark drawn in a square: play, pause, stop, step, down (a menu's
arrow), right and open (a tree's arrows), check, cross."""
def draw_glyph(canvas: Canvas, name: str, x: int, y: int, side: int, color: Ink) {
    if name == "play" or name == "right" {
        canvas.triangle(x, y, x, y + side, x + side, y + side // 2, color);
    } elif name == "open" or name == "down" {
        canvas.triangle(x, y + side // 4, x + side // 2, y + side - side // 4, x + side, y + side // 4, color);
    } elif name == "pause" {
        bar = max(2, side // 3);
        canvas.fill(Rect(x=x, y=y, w=bar, h=side), color);
        canvas.fill(Rect(x=x + side - bar, y=y, w=bar, h=side), color);
    } elif name == "stop" {
        canvas.fill(Rect(x=x, y=y, w=side, h=side), color);
    } elif name == "step" {
        bar = max(2, side // 4);
        canvas.triangle(x, y, x, y + side, x + side - bar, y + side // 2, color);
        canvas.fill(Rect(x=x + side - bar, y=y, w=bar, h=side), color);
    } elif name == "check" {
        canvas.fill(Rect(x=x + 2, y=y + 2, w=side - 4, h=side - 4), color);
    } elif name == "cross" {
        canvas.line(x, y, x + side, y + side, color);
        canvas.line(x + side, y, x, y + side, color);
    }
}

"""A check box with its label. Clicking asks for `command` followed by 1 or
0."""
node Check(Widget) {
    has text: str = "",
        command: str = "",
        on_now: bool = False;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        if across {
            return canvas.theme.row + canvas.text_width(self.text) + canvas.theme.pad;
        }
        return canvas.theme.row;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        side = 14;
        box = Rect(x=self.area.x + 2, y=self.area.y + (self.area.h - side) // 2, w=side, h=side);
        canvas.fill(box, theme.hover if self.hovered else theme.field);
        canvas.outline(box, theme.border);
        if self.on_now {
            canvas.fill(box.inset(3), theme.accent);
        }
        canvas.label(
            self.text,
            Rect(x=box.right() + 6, y=self.area.y, w=self.area.right() - box.right() - 6, h=self.area.h),
            theme.text if self.enabled else theme.faint
        );
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" and event.button == 0 {
            self.on_now = not self.on_now;
            if self.command {
                stage.emit(self.command + " " + ("1" if self.on_now else "0"));
            }
            return True;
        }
        return event.kind in ["press", "release", "double", "drag"];
    }

    def solid -> bool {
        return True;
    }
}

"""A line of editable text. Enter (or leaving the field) asks for `command`
followed by the quoted text; Escape puts the old text back. A `live` field
also asks on every change, for searches and filters."""
node TextField(Widget) {
    has value: str = "",
        draft: str = "",
        command: str = "",
        ghost: str = "",
        live: bool = False,
        # Where the cursor is, where the selection began, and how far the
        # text has scrolled, in characters and screen units.
        cursor: int = 0,
        anchor: int = 0,
        scroll: int = 0,
        editing: bool = False;

    """Show `text` as the committed value (no command is asked for)."""
    def show(text: str) {
        self.value = text;
        if not self.editing {
            self.draft = text;
        }
    }

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 120 if across else canvas.theme.row;
    }

    def text_now -> str {
        return self.draft if self.editing else self.value;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.field);
        canvas.outline(self.area, theme.accent if self.focused else (theme.dim if self.hovered else theme.border));
        inner = Rect(x=self.area.x + 5, y=self.area.y, w=self.area.w - 10, h=self.area.h);
        text = self.text_now();
        canvas.clip(inner.within(self.clip));
        if not text and not self.focused {
            canvas.label(self.ghost, inner, theme.faint);
        }
        top = inner.y + (inner.h - theme.font) // 2;
        if self.focused {
            low = min(self.cursor, self.anchor);
            high = max(self.cursor, self.anchor);
            if high > low {
                x0 = inner.x - self.scroll + canvas.text_width(text[:low]);
                x1 = inner.x - self.scroll + canvas.text_width(text[:high]);
                canvas.fill(Rect(x=x0, y=top - 1, w=x1 - x0, h=theme.font + 3), theme.select);
            }
        }
        canvas.text(text, inner.x - self.scroll, top, theme.text if self.enabled else theme.faint);
        # The cursor blinks on the interface's clock.
        if self.focused and int(canvas.clock * 2.0) % 2 == 0 {
            x = inner.x - self.scroll + canvas.text_width(text[:self.cursor]);
            canvas.fill(Rect(x=x, y=top - 1, w=1, h=theme.font + 3), theme.text);
        }
        canvas.clip(self.clip);
    }

    """The character boundary nearest a screen x."""
    def index_at(canvas: Canvas, x: int) -> int {
        target = x - (self.area.x + 5) + self.scroll;
        text = self.draft;
        best = 0;
        gap = abs(target);
        for i in range(1, len(text) + 1) {
            off = abs(canvas.text_width(text[:i]) - target);
            if off < gap {
                gap = off;
                best = i;
            }
        }
        return best;
    }

    """Keep the cursor inside the field."""
    def follow(canvas: Canvas) {
        room = max(1, self.area.w - 10);
        at = canvas.text_width(self.draft[:self.cursor]);
        if at - self.scroll > room - 2 {
            self.scroll = at - room + 2;
        }
        if at - self.scroll < 0 {
            self.scroll = at;
        }
        self.scroll = max(0, self.scroll);
    }

    def commit(stage: Stage) {
        if not self.editing {
            return;
        }
        self.editing = False;
        changed = self.draft != self.value;
        self.value = self.draft;
        self.scroll = 0;
        if changed and self.command and not self.live {
            stage.emit(self.command + " " + quote_command_word(self.value));
        }
    }

    def replace_selection(text: str) {
        low = min(self.cursor, self.anchor);
        high = max(self.cursor, self.anchor);
        self.draft = self.draft[:low] + text + self.draft[high:];
        self.cursor = low + len(text);
        self.anchor = self.cursor;
    }

    def changed(stage: Stage) {
        self.follow(stage.canvas);
        if self.live and self.command {
            stage.emit(self.command + " " + quote_command_word(self.draft));
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        if kind == "focus" {
            self.editing = True;
            self.draft = self.value;
            self.cursor = len(self.draft);
            self.anchor = 0;
            return True;
        }
        if kind == "blur" {
            self.commit(stage);
            return True;
        }
        if kind == "press" {
            self.cursor = self.index_at(stage.canvas, event.x);
            if not event.shift {
                self.anchor = self.cursor;
            }
            return True;
        }
        if kind == "double" {
            self.anchor = 0;
            self.cursor = len(self.draft);
            return True;
        }
        if kind == "drag" {
            self.cursor = self.index_at(stage.canvas, event.x);
            self.follow(stage.canvas);
            return True;
        }
        if kind == "text" {
            self.replace_selection(event.text);
            self.changed(stage);
            return True;
        }
        if kind == "key" {
            return self.key(event, stage);
        }
        return kind in ["release", "click"];
    }

    def key(event: UiEvent, stage: Stage) -> bool {
        key = event.key;
        selected = self.cursor != self.anchor;
        if key == "ENTER" or key == "KP_ENTER" {
            stage.focus_on(None);
            return True;
        }
        if key == "ESCAPE" {
            self.draft = self.value;
            self.editing = False;
            stage.focus_on(None);
            return True;
        }
        if key == "TAB" {
            stage.focus_on(None);
            return False;
        }
        if event.ctrl and key == "a" {
            self.anchor = 0;
            self.cursor = len(self.draft);
            return True;
        }
        if event.ctrl and (key == "c" or key == "x") {
            low = min(self.cursor, self.anchor);
            high = max(self.cursor, self.anchor);
            if high > low {
                stage.canvas.copy(self.draft[low:high]);
                if key == "x" {
                    self.replace_selection("");
                    self.changed(stage);
                }
            }
            return True;
        }
        if event.ctrl and key == "v" {
            self.replace_selection(stage.canvas.copied().replace("\n", " "));
            self.changed(stage);
            return True;
        }
        if event.ctrl {
            # Other chords belong to the studio.
            return False;
        }
        if key == "BACKSPACE" or key == "DEL" {
            if not selected {
                if key == "BACKSPACE" and self.cursor > 0 {
                    self.anchor = self.cursor - 1;
                } elif key == "DEL" and self.cursor < len(self.draft) {
                    self.anchor = self.cursor + 1;
                }
            }
            self.replace_selection("");
            self.changed(stage);
            return True;
        }
        moved = True;
        if key == "LEFTARROW" {
            self.cursor = max(0, self.cursor - 1);
        } elif key == "RIGHTARROW" {
            self.cursor = min(len(self.draft), self.cursor + 1);
        } elif key == "HOME" {
            self.cursor = 0;
        } elif key == "END" {
            self.cursor = len(self.draft);
        } else {
            moved = False;
        }
        if moved {
            if not event.shift {
                self.anchor = self.cursor;
            }
            self.follow(stage.canvas);
            return True;
        }
        # Typed characters arrive as text; their key events stop here so they
        # are not taken for shortcuts.
        return len(key) == 1 or key == "SPACE";
    }

    def solid -> bool {
        return True;
    }

    def focusable -> bool {
        return self.enabled;
    }
}

"""A window onto one taller child, scrolled by the wheel or its bar."""
node Scroll(Widget) {
    has offset: int = 0,
        tall: int = 0,
        grabbing: bool = False;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        best = 0;
        for kid in self.kids() {
            best = max(best, kid.wanted(canvas, across));
        }
        return best + (canvas.theme.bar if across else 0);
    }

    def reach -> int {
        return max(0, self.tall - self.area.h);
    }

    def place(canvas: Canvas) {
        self.tall = 0;
        for kid in self.kids() {
            if kid.shown {
                self.tall = max(self.tall, kid.wanted(canvas, False));
            }
        }
        self.offset = max(0, min(self.offset, self.reach()));
        bar = canvas.theme.bar if self.reach() > 0 else 0;
        for kid in self.kids() {
            kid.area = Rect(
                x=self.area.x, y=self.area.y - self.offset, w=self.area.w - bar, h=max(self.tall, self.area.h)
            );
        }
    }

    def thumb(canvas: Canvas) -> Rect {
        bar = canvas.theme.bar;
        length = max(20, (self.area.h * self.area.h) // max(1, self.tall));
        travel = self.area.h - length;
        top = self.area.y + (travel * self.offset) // max(1, self.reach());
        return Rect(x=self.area.right() - bar, y=top, w=bar, h=length);
    }

    def draw_over(canvas: Canvas) {
        if self.reach() <= 0 {
            return;
        }
        theme = canvas.theme;
        canvas.fill(Rect(x=self.area.right() - theme.bar, y=self.area.y, w=theme.bar, h=self.area.h), theme.header);
        canvas.fill(self.thumb(canvas).inset(2), theme.dim if self.grabbing or self.hovered else theme.border);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "wheel" {
            if self.reach() <= 0 {
                return False;
            }
            self.offset = max(0, min(self.reach(), self.offset - int(event.wheel * 3.0 * float(stage.canvas.theme.row))));
            return True;
        }
        if event.kind == "press" {
            self.grabbing = event.x >= self.area.right() - stage.canvas.theme.bar;
            return True;
        }
        if event.kind == "drag" and self.grabbing {
            travel = max(1, self.area.h - self.thumb(stage.canvas).h);
            self.offset = max(0, min(self.reach(), self.offset + (event.dy * self.reach()) // travel));
            return True;
        }
        if event.kind == "release" {
            self.grabbing = False;
            return True;
        }
        return False;
    }

    def solid -> bool {
        return True;
    }
}

"""A bar between two widgets of a box that drags the length of `target`:
the widget before it when `after` is false, else the one after it."""
node Splitter(Widget) {
    has target: Widget | None = None,
        after: bool = False,
        low: int = 80,
        high: int = 1200;

    def wanted(canvas: Canvas, across: bool) -> int {
        return 5 if across == self.along else 0;
    }


    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.accent if self.held else (theme.dim if self.hovered else theme.window));
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        moved = self.target;
        if event.kind == "drag" and moved is not None {
            step = event.dx if self.along else event.dy;
            if self.after {
                step = -step;
            }
            moved.size = max(self.low, min(self.high, moved.size + step));
            return True;
        }
        return event.kind in ["press", "release", "click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""One row of a tree: `key` is what its commands name."""
obj TreeRow {
    has key: str,
        text: str,
        depth: int = 0,
        # Whether it has children, and whether they are showing.
        branch: bool = False,
        opened: bool = False,
        picked: bool = False,
        # Dim text at the right edge, and the tone of the row's text.
        note: str = "",
        tone: str = "text";
}

"""A scrolling list of rows, indented as a tree. The rows are data the owner
replaces; only the visible ones are drawn, so a level's thousand entities cost
no more than a screenful. A click asks for `pick` and the row's key (with
"add" when Ctrl or Shift is held), a click on a branch's arrow for `toggle`,
and a double click for `open`."""
node TreeView(Widget) {
    has rows: list[TreeRow] = [],
        pick: str = "",
        toggle: str = "",
        open_command: str = "",
        offset: int = 0,
        grabbing: bool = False,
        hover_row: int = -1,
        row_height: int = 20;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 160 if across else self.row_height * 6;
    }

    def reach -> int {
        return max(0, len(self.rows) * self.row_height - self.area.h);
    }

    """Scroll so a row shows."""
    def reveal(index: int) {
        top = index * self.row_height;
        if top < self.offset {
            self.offset = top;
        } elif top + self.row_height > self.offset + self.area.h {
            self.offset = top + self.row_height - self.area.h;
        }
    }

    def row_at(y: int) -> int {
        index = (y - self.area.y + self.offset) // self.row_height;
        return index if 0 <= index and index < len(self.rows) else -1;
    }

    def thumb(canvas: Canvas) -> Rect {
        bar = canvas.theme.bar;
        total = max(1, len(self.rows) * self.row_height);
        length = max(20, (self.area.h * self.area.h) // total);
        travel = self.area.h - length;
        top = self.area.y + (travel * self.offset) // max(1, self.reach());
        return Rect(x=self.area.right() - bar, y=top, w=bar, h=length);
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.panel);
        self.offset = max(0, min(self.offset, self.reach()));
        first = self.offset // self.row_height;
        last = min(len(self.rows), (self.offset + self.area.h) // self.row_height + 1);
        bar = theme.bar if self.reach() > 0 else 0;
        for i in range(first, last) {
            row = self.rows[i];
            line = Rect(
                x=self.area.x,
                y=self.area.y + i * self.row_height - self.offset,
                w=self.area.w - bar,
                h=self.row_height
            );
            if row.picked {
                canvas.fill(line, theme.select);
            } elif i == self.hover_row and self.hovered {
                canvas.fill(line, theme.hover);
            }
            x = line.x + 6 + row.depth * 14;
            if row.branch {
                draw_glyph(canvas, "open" if row.opened else "right", x, line.y + 6, 8, theme.dim);
            }
            x += 14;
            note_width = canvas.text_width(row.note, theme.small) + 14 if row.note else 0;
            canvas.label(
                row.text,
                Rect(x=x, y=line.y, w=line.right() - x - note_width, h=line.h),
                theme_ink(canvas, row.tone)
            );
            if row.note {
                canvas.label(
                    row.note,
                    Rect(x=line.right() - note_width, y=line.y, w=note_width, h=line.h),
                    theme.faint,
                    1,
                    6,
                    theme.small
                );
            }
        }
        if self.reach() > 0 {
            canvas.fill(Rect(x=self.area.right() - bar, y=self.area.y, w=bar, h=self.area.h), theme.header);
            canvas.fill(self.thumb(canvas).inset(2), theme.dim if self.grabbing else theme.border);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        bar = stage.canvas.theme.bar if self.reach() > 0 else 0;
        if kind == "wheel" {
            self.offset = max(0, min(self.reach(), self.offset - int(event.wheel * 3.0 * float(self.row_height))));
            return True;
        }
        if kind == "press" or kind == "double" {
            self.grabbing = bar > 0 and event.x >= self.area.right() - bar;
            if self.grabbing or event.button != 0 {
                return True;
            }
            index = self.row_at(event.y);
            if index < 0 {
                if self.pick {
                    stage.emit(self.pick);
                }
                return True;
            }
            row = self.rows[index];
            arrow = self.area.x + 6 + row.depth * 14;
            if row.branch and event.x >= arrow - 4 and event.x < arrow + 12 {
                stage.emit(self.toggle + " " + quote_command_word(row.key));
            } elif kind == "double" and self.open_command {
                stage.emit(self.open_command + " " + quote_command_word(row.key));
            } elif self.pick {
                stage.emit(
                    self.pick + " " + quote_command_word(row.key) + (" add" if event.ctrl or event.shift else "")
                );
            }
            return True;
        }
        if kind == "drag" {
            if self.grabbing {
                travel = max(1, self.area.h - self.thumb(stage.canvas).h);
                self.offset = max(0, min(self.reach(), self.offset + (event.dy * self.reach()) // travel));
            }
            return True;
        }
        if kind == "release" {
            self.grabbing = False;
            return True;
        }
        return kind == "click";
    }

    """Called every frame by the owner: which row the pointer is over."""
    def track(stage: Stage) {
        self.hover_row = self.row_at(stage.input.y) if self.hovered else -1;
    }

    def solid -> bool {
        return True;
    }
}

"""One picture of a gallery: `key` is what its command names and the image
the canvas keeps under that name."""
obj Tile {
    has key: str,
        text: str,
        picked: bool = False;
}

"""A scrolling wall of pictures with their names under them, as many across
as fit. A click asks for `pick` and the tile's key."""
node Gallery(Widget) {
    has tiles: list[Tile] = [],
        pick: str = "",
        offset: int = 0,
        tile: int = 72,
        gap: int = 6,
        grabbing: bool = False,
        hover_tile: int = -1;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 160 if across else self.pitch() * 2;
    }

    """A tile's height with its name and the gap under it."""
    def pitch -> int {
        return self.tile + 16 + self.gap;
    }

    def columns -> int {
        return max(1, (self.area.w - 10 - self.gap) // (self.tile + self.gap));
    }

    def reach -> int {
        rows = (len(self.tiles) + self.columns() - 1) // self.columns();
        return max(0, rows * self.pitch() + self.gap - self.area.h);
    }

    def tile_area(index: int) -> Rect {
        across = self.columns();
        return Rect(
            x=self.area.x + self.gap + (index % across) * (self.tile + self.gap),
            y=self.area.y + self.gap + (index // across) * self.pitch() - self.offset,
            w=self.tile,
            h=self.tile
        );
    }

    def tile_at(x: int, y: int) -> int {
        across = self.columns();
        column = (x - self.area.x - self.gap) // (self.tile + self.gap);
        row = (y - self.area.y - self.gap + self.offset) // self.pitch();
        if column < 0 or column >= across or row < 0 {
            return -1;
        }
        index = row * across + column;
        if index >= len(self.tiles) {
            return -1;
        }
        spot = self.tile_area(index);
        if x >= spot.x + spot.w {
            return -1;
        }
        return index;
    }

    """Scroll so a tile shows."""
    def reveal(index: int) {
        top = self.gap + (index // self.columns()) * self.pitch();
        if top < self.offset {
            self.offset = top - self.gap;
        } elif top + self.pitch() > self.offset + self.area.h {
            self.offset = top + self.pitch() - self.area.h;
        }
    }

    def thumb(canvas: Canvas) -> Rect {
        bar = canvas.theme.bar;
        total = max(1, self.reach() + self.area.h);
        length = max(20, (self.area.h * self.area.h) // total);
        travel = self.area.h - length;
        top = self.area.y + (travel * self.offset) // max(1, self.reach());
        return Rect(x=self.area.right() - bar, y=top, w=bar, h=length);
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.panel);
        self.offset = max(0, min(self.offset, self.reach()));
        for index in range(len(self.tiles)) {
            spot = self.tile_area(index);
            if spot.y + self.pitch() < self.area.y or spot.y > self.area.y + self.area.h {
                continue;
            }
            shown = self.tiles[index];
            if not canvas.picture(shown.key, spot) {
                canvas.fill(spot, theme.field);
            }
            if shown.picked {
                canvas.outline(Rect(x=spot.x - 2, y=spot.y - 2, w=spot.w + 4, h=spot.h + 4), theme.accent);
                canvas.outline(Rect(x=spot.x - 1, y=spot.y - 1, w=spot.w + 2, h=spot.h + 2), theme.accent);
            } elif index == self.hover_tile and self.hovered {
                canvas.outline(Rect(x=spot.x - 1, y=spot.y - 1, w=spot.w + 2, h=spot.h + 2), theme.text);
            }
            canvas.label(
                shown.text,
                Rect(x=spot.x, y=spot.y + spot.h + 1, w=spot.w, h=14),
                theme.text if shown.picked else theme.dim,
                0,
                0,
                theme.small
            );
        }
        if self.reach() > 0 {
            bar = theme.bar;
            canvas.fill(Rect(x=self.area.right() - bar, y=self.area.y, w=bar, h=self.area.h), theme.header);
            canvas.fill(self.thumb(canvas).inset(2), theme.dim if self.grabbing else theme.border);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        bar = stage.canvas.theme.bar if self.reach() > 0 else 0;
        if kind == "wheel" {
            self.offset = max(0, min(self.reach(), self.offset - int(event.wheel * float(self.pitch()))));
            return True;
        }
        if kind == "press" or kind == "double" {
            self.grabbing = bar > 0 and event.x >= self.area.right() - bar;
            if self.grabbing or event.button != 0 {
                return True;
            }
            index = self.tile_at(event.x, event.y);
            if index >= 0 and self.pick {
                stage.emit(self.pick + " " + quote_command_word(self.tiles[index].key));
            }
            return True;
        }
        if kind == "drag" {
            if self.grabbing {
                travel = max(1, self.area.h - self.thumb(stage.canvas).h);
                self.offset = max(0, min(self.reach(), self.offset + (event.dy * self.reach()) // travel));
            }
            return True;
        }
        if kind == "release" {
            self.grabbing = False;
            return True;
        }
        return kind == "click";
    }

    """Called every frame by the owner: which tile the pointer is over."""
    def track(stage: Stage) {
        self.hover_tile = self.tile_at(stage.input.x, stage.input.y) if self.hovered else -1;
    }

    def solid -> bool {
        return True;
    }
}

"""Pages behind a strip of titles; one page shows at a time."""
node Tabs(Widget) {
    has titles: list[str] = [],
        current: int = 0,
        command: str = "";

    def strip -> int {
        return 24;
    }

    def place(canvas: Canvas) {
        pages = self.kids();
        self.current = max(0, min(self.current, len(pages) - 1));
        body = Rect(
            x=self.area.x, y=self.area.y + self.strip(), w=self.area.w, h=max(0, self.area.h - self.strip())
        );
        for i in range(len(pages)) {
            pages[i].shown = i == self.current;
            pages[i].area = body;
        }
    }

    def title_area(canvas: Canvas, index: int) -> Rect {
        x = self.area.x;
        for i in range(len(self.titles)) {
            width = canvas.text_width(self.titles[i]) + 20;
            if i == index {
                return Rect(x=x, y=self.area.y, w=width, h=self.strip());
            }
            x += width;
        }
        return Rect();
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(Rect(x=self.area.x, y=self.area.y, w=self.area.w, h=self.strip()), theme.header);
        for i in range(len(self.titles)) {
            tab = self.title_area(canvas, i);
            if i == self.current {
                canvas.fill(tab, theme.panel);
                canvas.fill(Rect(x=tab.x, y=tab.y, w=tab.w, h=2), theme.accent);
            }
            canvas.label(self.titles[i], tab, theme.text if i == self.current else theme.dim, 0);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.y < self.area.y + self.strip() {
            for i in range(len(self.titles)) {
                if self.title_area(stage.canvas, i).holds(event.x, event.y) {
                    self.current = i;
                    if self.command {
                        stage.emit(self.command + " " + str(i));
                    }
                }
            }
            return True;
        }
        return False;
    }

    def solid -> bool {
        return True;
    }
}

"""One line of a menu: a command with its shortcut text, or a rule."""
obj MenuItem {
    has text: str = "",
        command: str = "",
        keys: str = "",
        rule: bool = False,
        ticked: bool = False,
        enabled: bool = True;
}

"""A list of commands that opens as a layer and closes on a choice."""
node MenuPopup(Widget) {
    has items: list[MenuItem] = [],
        hover_item: int = -1;

    def line_height(item: MenuItem) -> int {
        return 7 if item.rule else 22;
    }

    """Size the popup to its items and put its corner at a point, kept on
    the screen."""
    def open_at(stage: Stage, x: int, y: int) {
        canvas = stage.canvas;
        width = 140;
        height = 8;
        for item in self.items {
            height += self.line_height(item);
            wide = canvas.text_width(item.text) + 44;
            if item.keys {
                wide += canvas.text_width(item.keys, canvas.theme.small) + 24;
            }
            width = max(width, wide);
        }
        self.transient = True;
        self.area = Rect(
            x=max(0, min(x, stage.width - width)), y=max(0, min(y, stage.height - height)), w=width, h=height
        );
        stage.open(self);
    }

    def item_at(y: int) -> int {
        top = self.area.y + 4;
        for i in range(len(self.items)) {
            tall = self.line_height(self.items[i]);
            if y >= top and y < top + tall {
                return i;
            }
            top += tall;
        }
        return -1;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.raised);
        canvas.outline(self.area, theme.border);
        top = self.area.y + 4;
        for i in range(len(self.items)) {
            item = self.items[i];
            tall = self.line_height(item);
            line = Rect(x=self.area.x + 1, y=top, w=self.area.w - 2, h=tall);
            if item.rule {
                canvas.line(line.x + 6, top + 3, line.right() - 6, top + 3, theme.border);
            } else {
                lit = i == self.hover_item and item.enabled;
                if lit {
                    canvas.fill(line, theme.accent);
                }
                front = theme.on_accent if lit else (theme.text if item.enabled else theme.faint);
                if item.ticked {
                    draw_glyph(canvas, "check", line.x + 6, top + 6, 10, front);
                }
                canvas.label(item.text, Rect(x=line.x + 24, y=top, w=line.w - 30, h=tall), front);
                if item.keys {
                    canvas.label(
                        item.keys, line, theme.on_accent if lit else theme.faint, 1, 10, theme.small
                    );
                }
            }
            top += tall;
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" or event.kind == "release" {
            index = self.item_at(event.y);
            if index >= 0 and self.area.holds(event.x, event.y) {
                item = self.items[index];
                if item.enabled and not item.rule {
                    stage.close(self);
                    stage.emit(item.command);
                }
            }
            return True;
        }
        return True;
    }

    """Called every frame while open: which item the pointer is over."""
    def track(stage: Stage) {
        inside = self.area.holds(stage.input.x, stage.input.y);
        self.hover_item = self.item_at(stage.input.y) if inside else -1;
    }

    def solid -> bool {
        return True;
    }
}

"""The strip of menu titles along the top of the window."""
node MenuBar(Widget) {
    has titles: list[str] = [],
        menus: list[list[MenuItem]] = [],
        showing: int = -1,
        popup: MenuPopup | None = None;

    def wanted(canvas: Canvas, across: bool) -> int {
        if across {
            total = 8;
            for title in self.titles {
                total += canvas.text_width(title) + 20;
            }
            return total;
        }
        return 24;
    }

    def title_area(canvas: Canvas, index: int) -> Rect {
        x = self.area.x + 4;
        for i in range(len(self.titles)) {
            width = canvas.text_width(self.titles[i]) + 20;
            if i == index {
                return Rect(x=x, y=self.area.y, w=width, h=self.area.h);
            }
            x += width;
        }
        return Rect();
    }

    def title_at(canvas: Canvas, x: int, y: int) -> int {
        for i in range(len(self.titles)) {
            if self.title_area(canvas, i).holds(x, y) {
                return i;
            }
        }
        return -1;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.header);
        for i in range(len(self.titles)) {
            title = self.title_area(canvas, i);
            if i == self.showing {
                canvas.fill(title, theme.raised);
            }
            canvas.label(self.titles[i], title, theme.text if i == self.showing else theme.dim, 0);
        }
    }

    def show(stage: Stage, index: int) {
        self.hide(stage);
        if index < 0 or index >= len(self.menus) {
            return;
        }
        popup = MenuPopup(items=self.menus[index]);
        title = self.title_area(stage.canvas, index);
        popup.open_at(stage, title.x, title.bottom());
        self.popup = popup;
        self.showing = index;
    }

    def hide(stage: Stage) {
        popup = self.popup;
        if popup is not None {
            stage.close(popup);
        }
        self.popup = None;
        self.showing = -1;
    }

    """Called every frame: follow the pointer across titles while a menu is
    open, and notice when the menu closed itself."""
    def track(stage: Stage) {
        popup = self.popup;
        if popup is None {
            return;
        }
        if popup not in stage.layers() {
            self.popup = None;
            self.showing = -1;
            return;
        }
        popup.track(stage);
        over = self.title_at(stage.canvas, stage.input.x, stage.input.y);
        if over >= 0 and over != self.showing {
            self.show(stage, over);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" {
            over = self.title_at(stage.canvas, event.x, event.y);
            if over >= 0 and over != self.showing {
                self.show(stage, over);
            } else {
                self.hide(stage);
            }
            return True;
        }
        return event.kind in ["release", "click", "drag", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""The part of the window a scene shows through. It keeps the events that
reached it for the studio to read each frame."""
node ViewArea(Widget) {
    has events: list[UiEvent] = [];

    def on(event: UiEvent, stage: Stage) -> bool {
        # Keys are the studio's shortcuts whether or not the view has the
        # keyboard: they pass on.
        if event.kind == "key" or event.kind == "text" {
            return False;
        }
        self.events.append(event);
        return True;
    }

    def take -> list[UiEvent] {
        taken = self.events;
        self.events = [];
        return taken;
    }

    def draw(canvas: Canvas) {
        if self.focused {
            canvas.outline(self.area, canvas.theme.accent.faded(140));
        }
    }

    def solid -> bool {
        return True;
    }

    def focusable -> bool {
        return True;
    }
}
