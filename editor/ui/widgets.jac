"""The studio's controls: boxes that lay their children out in a row or a
column, and the labels, buttons, fields, lists, menus and splitters inside
them. Each is a Widget node; see widget.jac for how they are laid out, drawn
and fed input."""
import from .canvas { Canvas, Rect, Ink, rects_outside }
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
        tone: str = "text",
        # A row that stays where it is: it is not offered to be dragged.
        fixed: bool = False;
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
        # When set, a row that is not a heading is offered when pressed, to
        # be dragged elsewhere, as this word and the row's key.
        drag: str = "",
        # When set, something dragged and let go on this list asks for this
        # word with the key of the row it was let go on (empty when on
        # none) and what was carried.
        drop: str = "",
        # Whether headings are offered to be dragged as other rows are.
        carry_branches: bool = False,
        # A heading pressed where headings are carried: what a click on it
        # asks for is kept until the button comes up without a drag.
        pending: str = "",
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
            self.pending = "";
            if row.branch and event.x >= arrow - 4 and event.x < arrow + 12 {
                stage.emit(self.toggle + " " + quote_command_word(row.key));
            } elif row.branch and self.carry_branches and self.drag and self.pick and kind == "press" {
                # Opened by the click it becomes, not by the press: it may be carried away instead.
                self.pending = self.pick + " " + quote_command_word(row.key);
            } elif kind == "double" and self.open_command {
                stage.emit(self.open_command + " " + quote_command_word(row.key));
            } elif self.pick {
                stage.emit(
                    self.pick + " " + quote_command_word(row.key) + (" add" if event.ctrl or event.shift else "")
                );
            }
            if self.drag and (self.carry_branches or not row.branch) and not row.fixed {
                # A row that is a thing, not a heading, can be dragged elsewhere.
                stage.offer(self.drag + " " + row.key, row.text);
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
        if kind == "click" and self.pending {
            if not stage.carrying {
                stage.emit(self.pending);
            }
            self.pending = "";
            return True;
        }
        if kind == "drop" {
            if self.drop {
                index = self.row_at(event.y);
                stage.emit(
                    self.drop + " " + quote_command_word(self.rows[index].key if index >= 0 else "") + " "
                        + quote_command_word(event.text)
                );
            }
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
        # When set, a tile pressed is offered to be dragged elsewhere, as
        # this word and the tile's key.
        drag: str = "",
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
            if index >= 0 and self.drag {
                stage.offer(self.drag + " " + self.tiles[index].key, self.tiles[index].key);
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
        hover_item: int = -1,
        # A menu too long for the window goes on in further columns: the
        # item each column begins with, and how wide each column is.
        starts: list[int] = [0],
        widths: list[int] = [];

    def line_height(item: MenuItem) -> int {
        return 7 if item.rule else 22;
    }

    """How wide an item needs the popup to be."""
    def line_width(canvas: Canvas, item: MenuItem) -> int {
        wide = canvas.text_width(item.text) + 44;
        if item.keys {
            wide += canvas.text_width(item.keys, canvas.theme.small) + 24;
        }
        return wide;
    }

    """Size the popup to its items and put its corner at a point, kept on
    the screen. One too long for the window is laid out in columns under
    that point, each as long as the window leaves room for."""
    def open_at(stage: Stage, x: int, y: int) {
        canvas = stage.canvas;
        height = 8;
        for item in self.items {
            height += self.line_height(item);
        }
        self.starts = [0];
        tallest = height;
        if height > stage.height and stage.height > 0 {
            room = max(120, stage.height - y - 8);
            used = 8;
            tallest = 8;
            for (index, item) in enumerate(self.items) {
                tall = self.line_height(item);
                if used + tall > room and index > self.starts[-1] {
                    self.starts.append(index);
                    used = 8;
                }
                used += tall;
                tallest = max(tallest, used);
            }
        }
        self.widths = [];
        for (place, first) in enumerate(self.starts) {
            last = self.starts[place + 1] if place + 1 < len(self.starts) else len(self.items);
            width = 140;
            for item in self.items[first:last] {
                width = max(width, self.line_width(canvas, item));
            }
            self.widths.append(width);
        }
        across = sum(self.widths);
        self.transient = True;
        self.area = Rect(
            x=max(0, min(x, stage.width - across)), y=max(0, min(y, stage.height - tallest)), w=across, h=tallest
        );
        stage.open(self);
    }

    """A column's items (first, one past the last) and where it begins across."""
    def column(place: int) -> list[int] {
        first = self.starts[place];
        last = self.starts[place + 1] if place + 1 < len(self.starts) else len(self.items);
        left = self.area.x;
        for width in self.widths[:place] {
            left += width;
        }
        return [first, last, left];
    }

    def item_at(x: int, y: int) -> int {
        for place in range(min(len(self.starts), len(self.widths))) {
            span = self.column(place);
            if x < span[2] or x >= span[2] + self.widths[place] {
                continue;
            }
            top = self.area.y + 4;
            for i in range(span[0], span[1]) {
                tall = self.line_height(self.items[i]);
                if y >= top and y < top + tall {
                    return i;
                }
                top += tall;
            }
        }
        return -1;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.raised);
        canvas.outline(self.area, theme.border);
        for place in range(min(len(self.starts), len(self.widths))) {
            span = self.column(place);
            top = self.area.y + 4;
            if place > 0 {
                canvas.line(span[2], self.area.y + 4, span[2], self.area.bottom() - 4, theme.border);
            }
            for i in range(span[0], span[1]) {
                item = self.items[i];
                tall = self.line_height(item);
                line = Rect(x=span[2] + 1, y=top, w=self.widths[place] - 2, h=tall);
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
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" or event.kind == "release" {
            index = self.item_at(event.x, event.y);
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
        self.hover_item = self.item_at(stage.input.x, stage.input.y) if inside else -1;
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
    has events: list[UiEvent] = [],
        # Whether it shows that it has the keyboard (a view inside a
        # floating window does not: another window may lie over it).
        plain: bool = False;

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
        if self.focused and not self.plain {
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

"""One box of a graph view: `key` is what its commands name; `column` and
`row` say where it stands."""
obj GraphNode {
    has key: str,
        text: str,
        note: str = "",
        column: int = 0,
        row: int = 0,
        tone: str = "text",
        picked: bool = False;
}

"""An arrow of a graph view, from one box's key to another's."""
obj GraphLink {
    has source: str,
        dest: str,
        tone: str = "good";
}

"""Boxes in columns joined by arrows, on a sheet that slides under a drag on
its background and under the wheel. A click on a box asks for `pick` and its
key (a click on the sheet for `pick` alone), a double click for `open`, and
a drag from one box to another for `link` with both keys."""
node GraphView(Widget) {
    has nodes: list[GraphNode] = [],
        links: list[GraphLink] = [],
        pick: str = "",
        open_command: str = "",
        link: str = "",
        # What the sheet says when it has no boxes.
        empty: str = "",
        slide_x: int = 0,
        slide_y: int = 0,
        pitch_x: int = 200,
        pitch_y: int = 52,
        box_w: int = 156,
        box_h: int = 38,
        # The box an arrow is being pulled from, and where the pointer is.
        pulling: int = -1,
        pull_x: int = 0,
        pull_y: int = 0,
        sliding: bool = False,
        travelled: int = 0,
        hover_node: int = -1;

    def node_area(index: int) -> Rect {
        shown = self.nodes[index];
        return Rect(
            x=self.area.x + 24 + shown.column * self.pitch_x + self.slide_x,
            y=self.area.y + 30 + shown.row * self.pitch_y + self.slide_y,
            w=self.box_w,
            h=self.box_h
        );
    }

    def node_at(x: int, y: int) -> int {
        for index in range(len(self.nodes)) {
            if self.node_area(index).holds(x, y) {
                return index;
            }
        }
        return -1;
    }

    def index_of(key: str) -> int {
        for index in range(len(self.nodes)) {
            if self.nodes[index].key == key {
                return index;
            }
        }
        return -1;
    }

    """Slide the sheet so a box shows."""
    def reveal(index: int) {
        if index < 0 or index >= len(self.nodes) {
            return;
        }
        spot = self.node_area(index);
        if spot.x < self.area.x + 8 {
            self.slide_x += self.area.x + 24 - spot.x;
        } elif spot.x + spot.w > self.area.x + self.area.w - 8 {
            self.slide_x -= spot.x + spot.w - (self.area.x + self.area.w - 24);
        }
        if spot.y < self.area.y + 8 {
            self.slide_y += self.area.y + 30 - spot.y;
        } elif spot.y + spot.h > self.area.y + self.area.h - 8 {
            self.slide_y -= spot.y + spot.h - (self.area.y + self.area.h - 24);
        }
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.field);
        if len(self.nodes) == 0 and self.empty {
            canvas.label(self.empty, self.area, theme.faint, 0);
        }
        for arrow in self.links {
            source = self.index_of(arrow.source);
            dest = self.index_of(arrow.dest);
            if source < 0 or dest < 0 {
                continue;
            }
            start = self.node_area(source);
            finish = self.node_area(dest);
            color = theme_ink(canvas, arrow.tone);
            tip_x = finish.x - 1;
            tip_y = finish.y + finish.h // 2;
            canvas.line(start.x + start.w, start.y + start.h // 2, tip_x - 7, tip_y, color);
            canvas.triangle(tip_x - 8, tip_y - 4, tip_x - 8, tip_y + 5, tip_x, tip_y, color);
        }
        for index in range(len(self.nodes)) {
            shown = self.nodes[index];
            spot = self.node_area(index);
            back = theme.raised;
            if shown.picked {
                back = theme.select;
            } elif index == self.hover_node and self.hovered {
                back = theme.hover;
            }
            canvas.fill(spot, back);
            canvas.outline(spot, theme.accent if shown.picked or index == self.pulling else theme.border);
            canvas.label(
                shown.text,
                Rect(x=spot.x, y=spot.y + 2, w=spot.w, h=spot.h // 2),
                theme_ink(canvas, shown.tone),
                -1,
                8
            );
            if shown.note {
                canvas.label(
                    shown.note,
                    Rect(x=spot.x, y=spot.y + spot.h // 2 - 1, w=spot.w, h=spot.h // 2),
                    theme.dim,
                    -1,
                    8,
                    theme.small
                );
            }
        }
        if self.pulling >= 0 and self.pulling < len(self.nodes) and self.travelled > 4 {
            start = self.node_area(self.pulling);
            canvas.line(start.x + start.w, start.y + start.h // 2, self.pull_x, self.pull_y, theme.accent);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        kind = event.kind;
        if kind == "wheel" {
            if event.shift {
                self.slide_x += int(event.wheel * float(self.pitch_x) * 0.5);
            } else {
                self.slide_y += int(event.wheel * float(self.pitch_y));
            }
            return True;
        }
        if kind == "press" or kind == "double" {
            index = self.node_at(event.x, event.y);
            self.travelled = 0;
            self.pull_x = event.x;
            self.pull_y = event.y;
            if kind == "double" and index >= 0 and self.open_command {
                stage.emit(self.open_command + " " + quote_command_word(self.nodes[index].key));
                return True;
            }
            if event.button == 0 and index >= 0 {
                self.pulling = index;
            } else {
                self.sliding = True;
            }
            return True;
        }
        if kind == "drag" {
            self.travelled += abs(event.dx) + abs(event.dy);
            self.pull_x = event.x;
            self.pull_y = event.y;
            if self.sliding {
                self.slide_x += event.dx;
                self.slide_y += event.dy;
            }
            return True;
        }
        if kind == "release" {
            over = self.node_at(event.x, event.y);
            if self.pulling >= 0 and self.pulling < len(self.nodes) {
                if over >= 0 and over != self.pulling {
                    if self.link {
                        stage.emit(
                            self.link + " " + quote_command_word(self.nodes[self.pulling].key) + " "
                                + quote_command_word(self.nodes[over].key)
                        );
                    }
                } elif over == self.pulling and self.pick {
                    stage.emit(
                        self.pick + " " + quote_command_word(self.nodes[over].key)
                            + (" add" if event.ctrl or event.shift else "")
                    );
                }
            } elif self.sliding and self.travelled < 4 and event.button == 0 and self.pick {
                stage.emit(self.pick);
            }
            self.pulling = -1;
            self.sliding = False;
            return True;
        }
        return kind == "click";
    }

    """Called every frame by the owner: which box the pointer is over."""
    def track(stage: Stage) {
        self.hover_node = self.node_at(stage.input.x, stage.input.y) if self.hovered else -1;
    }

    def solid -> bool {
        return True;
    }
}

"""One value from a list: it shows the chosen label, and a click opens the
list under it. Choosing a label asks for the command beside it."""
node Dropdown(Widget) {
    has text: str = "",
        labels: list[str] = [],
        commands: list[str] = [];

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        if across {
            return canvas.text_width(self.text) + 2 * canvas.theme.pad + 18;
        }
        return canvas.theme.row + 2;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.hover if self.hovered else theme.field);
        canvas.outline(self.area, theme.border);
        canvas.label(
            self.text,
            Rect(x=self.area.x, y=self.area.y, w=self.area.w - 16, h=self.area.h),
            theme.text if self.enabled else theme.faint,
            -1,
            theme.pad
        );
        draw_glyph(canvas, "down", self.area.right() - 14, self.area.y + (self.area.h - 8) // 2, 8, theme.dim);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" and event.button == 0 and self.enabled {
            items: list[MenuItem] = [];
            for index in range(len(self.labels)) {
                items.append(
                    MenuItem(
                        text=self.labels[index],
                        command=self.commands[index] if index < len(self.commands) else "",
                        ticked=self.labels[index] == self.text
                    )
                );
            }
            if len(items) > 0 {
                popup = MenuPopup(items=items);
                popup.open_at(stage, self.area.x, self.area.bottom());
            }
            return True;
        }
        return event.kind in ["press", "release", "double", "drag"];
    }

    def solid -> bool {
        return True;
    }
}

"""A patch of one colour: red, green and blue as parts of one."""
node Swatch(Widget) {
    has red: float = 1.0,
        green: float = 1.0,
        blue: float = 1.0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return canvas.theme.row + 2;
    }

    def draw(canvas: Canvas) {
        canvas.fill(
            self.area,
            Ink(
                r=int(max(0.0, min(1.0, self.red)) * 255.0),
                g=int(max(0.0, min(1.0, self.green)) * 255.0),
                b=int(max(0.0, min(1.0, self.blue)) * 255.0),
                a=255
            )
        );
        canvas.outline(self.area, canvas.theme.border);
    }
}

"""A kept image shown as large as fits, in proportion, on a dark ground."""
node Picture(Widget) {
    has key: str = "";

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 128;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.field);
        size = canvas.picture_size(self.key);
        if size[0] <= 0 or size[1] <= 0 or self.area.w <= 8 or self.area.h <= 8 {
            return;
        }
        room_w = self.area.w - 8;
        room_h = self.area.h - 8;
        # Small images are shown larger by whole steps, so their texels stay square.
        wide = size[0];
        tall = size[1];
        if wide * room_h > tall * room_w {
            tall = max(1, tall * room_w // wide);
            wide = room_w;
        } else {
            wide = max(1, wide * room_h // tall);
            tall = room_h;
        }
        canvas.picture(
            self.key,
            Rect(
                x=self.area.x + (self.area.w - wide) // 2, y=self.area.y + (self.area.h - tall) // 2, w=wide, h=tall
            )
        );
    }
}

"""One thing a palette can run: the words that run it, how it is used, and
what it does."""
obj PaletteEntry {
    has command: str,
        usage: str = "",
        about: str = "";
}

"""How well typed letters find an entry: 4 when its command begins with
them, 3 when it holds them, 2 when its description does, 1 when the letters
appear in the command in that order, 0 when they do not find it."""
def palette_score(typed: str, found: PaletteEntry) -> int {
    wanted = typed.lower().strip();
    if not wanted {
        return 1;
    }
    name = found.command.lower();
    if name.startswith(wanted) {
        return 4;
    }
    if wanted in name {
        return 3;
    }
    if wanted in found.about.lower() {
        return 2;
    }
    at = 0;
    for letter in name {
        if at < len(wanted) and letter == wanted[at] {
            at += 1;
        }
    }
    return 1 if at == len(wanted) else 0;
}

"""A line to type into with the commands that match it listed beneath, best
first. Enter runs the one that is lit, or what was typed when it has words
after the command; the arrows move the light; Escape closes it. It opens as
a layer over the middle of the window and takes the keyboard."""
node Palette(Widget) {
    has entries: list[PaletteEntry] = [],
        typed: str = "",
        lit: int = 0,
        rows: int = 12;

    """The entries the typed letters find, best first."""
    def matches -> list[PaletteEntry] {
        found: list[PaletteEntry] = [];
        for score in [4, 3, 2, 1] {
            for known in self.entries {
                if palette_score(self.typed.split(" ")[0], known) == score {
                    found.append(known);
                }
            }
        }
        return found;
    }

    def open_in(stage: Stage) {
        wide = min(620, max(240, stage.width - 80));
        tall = 34 + self.rows * 22 + 8;
        self.transient = True;
        self.typed = "";
        self.lit = 0;
        self.area = Rect(x=(stage.width - wide) // 2, y=max(20, stage.height // 6), w=wide, h=tall);
        stage.open(self);
        stage.focus_on(self);
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.raised);
        canvas.outline(self.area, theme.accent);
        line = Rect(x=self.area.x + 6, y=self.area.y + 6, w=self.area.w - 12, h=24);
        canvas.fill(line, theme.field);
        canvas.outline(line, theme.border);
        if self.typed {
            canvas.label(self.typed, line, theme.text, -1, 6);
        } else {
            canvas.label("Type a command", line, theme.faint, -1, 6);
        }
        found = self.matches();
        self.lit = max(0, min(self.lit, len(found) - 1));
        first = max(0, self.lit - self.rows + 1);
        for shown in range(first, min(len(found), first + self.rows)) {
            row = Rect(x=self.area.x + 4, y=self.area.y + 36 + (shown - first) * 22, w=self.area.w - 8, h=22);
            if shown == self.lit {
                canvas.fill(row, theme.select);
            }
            name_wide = canvas.text_width(found[shown].command) + 16;
            canvas.label(found[shown].command, row, theme.text, -1, 6);
            canvas.label(
                found[shown].about,
                Rect(x=row.x + name_wide, y=row.y, w=row.w - name_wide, h=row.h),
                theme.dim,
                -1,
                6,
                theme.small
            );
        }
        if len(found) == 0 {
            canvas.label(
                "Nothing by that name: Enter runs what is typed",
                Rect(x=self.area.x + 4, y=self.area.y + 36, w=self.area.w - 8, h=22),
                theme.faint,
                -1,
                6
            );
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "text" {
            self.typed += event.text;
            self.lit = 0;
            return True;
        }
        if event.kind == "blur" {
            stage.close(self);
            return True;
        }
        if event.kind != "key" {
            return True;
        }
        key = event.key;
        found = self.matches();
        if key == "ESCAPE" {
            stage.close(self);
            stage.focus_on(None);
        } elif key == "BACKSPACE" {
            self.typed = self.typed[:-1];
            self.lit = 0;
        } elif key == "DOWNARROW" {
            self.lit = min(self.lit + 1, max(0, len(found) - 1));
        } elif key == "UPARROW" {
            self.lit = max(0, self.lit - 1);
        } elif key == "TAB" {
            # Take the lit command's name, ready for its words.
            if len(found) > 0 {
                self.typed = found[max(0, min(self.lit, len(found) - 1))].command + " ";
            }
        } elif key == "ENTER" or key == "KP_ENTER" {
            words = self.typed.strip();
            if " " not in words and len(found) > 0 {
                words = found[max(0, min(self.lit, len(found) - 1))].command;
            }
            stage.close(self);
            stage.focus_on(None);
            if words {
                stage.emit(words);
            }
        }
        return True;
    }

    def solid -> bool {
        return True;
    }

    def focusable -> bool {
        return True;
    }
}

"""A number as a control shows and sends it: whole when it is whole."""
def number_words(value: float) -> str {
    nearest = float(round(value));
    return str(int(nearest)) if abs(value - nearest) < 0.0005 else str(round(value, 2));
}

"""A number chosen by dragging a knob along a bar, between `low` and `high`
in steps of `step` (any value when it is zero). The command goes out, with
the number after it, when the knob is let go."""
node Slider(Widget) {
    has low: float = 0.0,
        high: float = 1.0,
        value: float = 0.0,
        step: float = 0.0,
        command: str = "",
        # What it had when the knob was taken, to tell whether it changed.
        taken: float = 0.0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 120 if across else canvas.theme.row;
    }

    """How far along the bar the knob is, from 0 to 1."""
    def fraction -> float {
        if self.high <= self.low {
            return 0.0;
        }
        return max(0.0, min(1.0, (self.value - self.low) / (self.high - self.low)));
    }

    """Put the knob under a point of the window."""
    def follow(x: int) {
        run = max(1, self.area.w - 12);
        share = max(0.0, min(1.0, float(x - self.area.x - 6) / float(run)));
        fresh = self.low + (self.high - self.low) * share;
        if self.step > 0.0 {
            fresh = self.low + float(round((fresh - self.low) / self.step)) * self.step;
        }
        self.value = max(self.low, min(self.high, fresh));
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        middle = self.area.y + self.area.h // 2;
        bar = Rect(x=self.area.x + 6, y=middle - 2, w=max(1, self.area.w - 12), h=4);
        canvas.fill(bar, theme.field);
        canvas.fill(Rect(x=bar.x, y=bar.y, w=int(float(bar.w) * self.fraction()), h=bar.h), theme.accent);
        knob = Rect(x=bar.x + int(float(bar.w) * self.fraction()) - 5, y=middle - 7, w=10, h=14);
        canvas.fill(knob, theme.hover if self.hovered or self.held else theme.raised);
        canvas.outline(knob, theme.border);
        canvas.label(number_words(self.value), self.area, theme.dim, 1, 14, theme.small);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.taken = self.value;
            self.follow(event.x);
            return True;
        }
        if event.kind == "drag" {
            self.follow(event.x);
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            if self.command and self.value != self.taken {
                stage.emit(self.command + " " + number_words(self.value));
            }
            return True;
        }
        return event.kind in ["click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""A number shown in a field and changed by dragging across it (a step a
few pixels, ten with Shift) or by the wheel. The command goes out, with the
number after it, when the drag ends or the wheel turns."""
node Spinner(Widget) {
    has value: float = 0.0,
        step: float = 1.0,
        low: float = -1000000.0,
        high: float = 1000000.0,
        command: str = "",
        text: str = "",
        # Where the drag began, and what the number was then.
        from_x: int = 0,
        taken: float = 0.0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 72 if across else canvas.theme.row;
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(self.area, theme.hover if self.hovered or self.held else theme.field);
        canvas.outline(self.area, theme.border);
        if self.text {
            canvas.label(self.text, self.area, theme.dim, -1, 6, theme.small);
        }
        canvas.label(number_words(self.value), self.area, theme.text, 1, 6);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.from_x = event.x;
            self.taken = self.value;
            return True;
        }
        if event.kind == "drag" {
            # A step every four pixels the pointer has gone from where it began.
            notches = float((event.x - self.from_x) // 4);
            self.value = max(
                self.low, min(self.high, self.taken + notches * self.step * (10.0 if event.shift else 1.0))
            );
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            if self.command and self.value != self.taken {
                stage.emit(self.command + " " + number_words(self.value));
            }
            return True;
        }
        if event.kind == "wheel" {
            before = self.value;
            self.value = max(self.low, min(self.high, self.value + self.step * (1.0 if event.wheel > 0.0 else -1.0)));
            if self.command and self.value != before {
                stage.emit(self.command + " " + number_words(self.value));
            }
            return True;
        }
        return event.kind in ["click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""One of several, side by side: a click on another makes it the one, and
runs that one's command."""
node Radio(Widget) {
    has labels: list[str] = [],
        commands: list[str] = [],
        chosen: int = 0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        if across {
            wide = 0;
            for label in self.labels {
                wide += canvas.text_width(label) + 2 * canvas.theme.pad + 6;
            }
            return wide;
        }
        return canvas.theme.row;
    }

    """Which label a point of the window is on, or -1."""
    def part_at(x: int) -> int {
        count = len(self.labels);
        if count == 0 or x < self.area.x or x >= self.area.right() {
            return -1;
        }
        return min(count - 1, (x - self.area.x) * count // max(1, self.area.w));
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        count = max(1, len(self.labels));
        for (index, label) in enumerate(self.labels) {
            cell = Rect(
                x=self.area.x + self.area.w * index // count,
                y=self.area.y,
                w=self.area.w * (index + 1) // count - self.area.w * index // count,
                h=self.area.h
            );
            canvas.fill(cell.inset(1), theme.accent if index == self.chosen else theme.raised);
            canvas.label(label, cell, theme.header if index == self.chosen else theme.text, 0);
        }
        canvas.outline(self.area, theme.border);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "click" and event.button == 0 {
            picked = self.part_at(event.x);
            if picked >= 0 and picked != self.chosen {
                self.chosen = picked;
                if picked < len(self.commands) and self.commands[picked] {
                    stage.emit(self.commands[picked]);
                }
            }
            return True;
        }
        return event.kind in ["press", "release", "double", "drag"];
    }

    def solid -> bool {
        return True;
    }
}

"""Three numbers side by side, each changed by dragging across its own
cell; the command goes out with all three, as one word, when a drag ends."""
node VectorField(Widget) {
    has x: float = 0.0,
        y: float = 0.0,
        z: float = 0.0,
        step: float = 1.0,
        command: str = "",
        # Which cell a drag is in, where it began and what that number was.
        part: int = -1,
        from_x: int = 0,
        taken: float = 0.0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 180 if across else canvas.theme.row;
    }

    def number(index: int) -> float {
        return self.x if index == 0 else (self.y if index == 1 else self.z);
    }

    def put(index: int, value: float) {
        if index == 0 {
            self.x = value;
        } elif index == 1 {
            self.y = value;
        } else {
            self.z = value;
        }
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        for index in range(3) {
            cell = Rect(
                x=self.area.x + self.area.w * index // 3,
                y=self.area.y,
                w=self.area.w * (index + 1) // 3 - self.area.w * index // 3,
                h=self.area.h
            );
            canvas.fill(cell.inset(1), theme.hover if self.held and index == self.part else theme.field);
            canvas.label(["x", "y", "z"][index], cell, theme.faint, -1, 5, theme.small);
            canvas.label(number_words(self.number(index)), cell, theme.text, 1, 5);
        }
        canvas.outline(self.area, theme.border);
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.part = max(0, min(2, (event.x - self.area.x) * 3 // max(1, self.area.w)));
            self.from_x = event.x;
            self.taken = self.number(self.part);
            return True;
        }
        if event.kind == "drag" and self.part >= 0 {
            notches = float((event.x - self.from_x) // 4);
            self.put(self.part, self.taken + notches * self.step * (10.0 if event.shift else 1.0));
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            if self.part >= 0 and self.command and self.number(self.part) != self.taken {
                stage.emit(
                    self.command + " "
                        + quote_command_word(
                            number_words(self.x) + " " + number_words(self.y) + " " + number_words(self.z)
                        )
                );
            }
            self.part = -1;
            return True;
        }
        return event.kind in ["click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""A colour mixed from three bars, red, green and blue, each dragged along;
its patch shows the mix. The command goes out with the three shares (0 to
1), as one word, when a drag ends."""
node ColourBars(Widget) {
    has red: float = 1.0,
        green: float = 1.0,
        blue: float = 1.0,
        command: str = "",
        part: int = -1,
        taken: float = 0.0;

    def wanted(canvas: Canvas, across: bool) -> int {
        if self.fixed(across) > 0 {
            return self.size;
        }
        return 160 if across else 3 * 14 + 6;
    }

    def share(index: int) -> float {
        return self.red if index == 0 else (self.green if index == 1 else self.blue);
    }

    """The bar a row of the window is on, and the area of bar `index`."""
    def bar(index: int) -> Rect {
        return Rect(x=self.area.x + 40, y=self.area.y + 3 + index * 14, w=max(1, self.area.w - 46), h=12);
    }

    def follow(x: int) {
        where = self.bar(self.part);
        value = max(0.0, min(1.0, float(x - where.x) / float(where.w)));
        value = float(round(value * 100.0)) / 100.0;
        if self.part == 0 {
            self.red = value;
        } elif self.part == 1 {
            self.green = value;
        } elif self.part == 2 {
            self.blue = value;
        }
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        canvas.fill(
            Rect(x=self.area.x + 2, y=self.area.y + 3, w=32, h=self.area.h - 6),
            Ink(r=int(self.red * 255.0), g=int(self.green * 255.0), b=int(self.blue * 255.0), a=255)
        );
        canvas.outline(Rect(x=self.area.x + 2, y=self.area.y + 3, w=32, h=self.area.h - 6), theme.border);
        tones = [Ink(r=229, g=72, b=77, a=255), Ink(r=76, g=195, b=138, a=255), Ink(r=91, g=141, b=239, a=255)];
        for index in range(3) {
            where = self.bar(index);
            canvas.fill(where, theme.field);
            canvas.fill(Rect(x=where.x, y=where.y, w=int(float(where.w) * self.share(index)), h=where.h), tones[index]);
        }
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.part = max(0, min(2, (event.y - self.area.y - 3) // 14));
            self.taken = self.share(self.part);
            self.follow(event.x);
            return True;
        }
        if event.kind == "drag" and self.part >= 0 {
            self.follow(event.x);
            return True;
        }
        if event.kind == "release" and event.button == 0 {
            if self.part >= 0 and self.command and self.share(self.part) != self.taken {
                stage.emit(
                    self.command + " "
                        + quote_command_word(
                            number_words(self.red) + " " + number_words(self.green) + " " + number_words(self.blue)
                        )
                );
            }
            self.part = -1;
            return True;
        }
        return event.kind in ["click", "double"];
    }

    def solid -> bool {
        return True;
    }
}

"""A window that floats over the rest as a layer of its own, with one widget
inside it. It is dragged by the bar along its top, sized by the corner at
its bottom right, and its cross asks for `command`. What is inside is left
unpainted, for a view to show through."""
node Floater(Widget) {
    has title: str = "",
        command: str = "",
        # What it says along its bottom edge, beside the corner.
        note: str = "",
        bar: int = 20,
        foot: int = 14,
        least_wide: int = 140,
        least_tall: int = 100,
        # Where it may go: the whole stage, unless this has a size.
        bounds: Rect = Rect(),
        # What lies over it (other windows that float above): it paints
        # nothing there, having left its inside unpainted for them too.
        covered: list[Rect] = [],
        # What a press took hold of: "move", "size" or "".
        taken: str = "";

    """The cross at the end of the bar."""
    def cross -> Rect {
        return Rect(x=self.area.right() - self.bar, y=self.area.y, w=self.bar, h=self.bar);
    }

    """The corner it is sized by."""
    def corner -> Rect {
        return Rect(x=self.area.right() - self.foot, y=self.area.bottom() - self.foot, w=self.foot, h=self.foot);
    }

    """Where the widget inside goes: under the bar, over the foot."""
    def inside -> Rect {
        return Rect(
            x=self.area.x + 1,
            y=self.area.y + self.bar,
            w=max(0, self.area.w - 2),
            h=max(0, self.area.h - self.bar - self.foot)
        );
    }

    def place(canvas: Canvas) {
        for kid in self.kids() {
            kid.area = self.inside();
        }
    }

    def draw(canvas: Canvas) {
        theme = canvas.theme;
        top = Rect(x=self.area.x, y=self.area.y, w=self.area.w, h=self.bar);
        base = Rect(x=self.area.x, y=self.area.bottom() - self.foot, w=self.area.w, h=self.foot);
        for piece in rects_outside(self.clip, self.covered) {
            canvas.clip(piece);
            canvas.fill(top, theme.header);
            canvas.label(
                self.title, Rect(x=top.x + 6, y=top.y, w=max(0, top.w - self.bar - 8), h=top.h), theme.text, -1, 0, theme.small
            );
            draw_glyph(canvas, "cross", self.cross().x + 6, self.cross().y + 6, self.bar - 12, theme.dim);
            canvas.fill(base, theme.header);
            canvas.label(
                self.note, Rect(x=base.x + 6, y=base.y, w=max(0, base.w - self.foot - 8), h=base.h), theme.faint, -1, 0, theme.small
            );
        }
        canvas.clip(self.clip);
    }

    def draw_over(canvas: Canvas) {
        theme = canvas.theme;
        grip = self.corner();
        for piece in rects_outside(self.clip, self.covered) {
            canvas.clip(piece);
            canvas.outline(self.area, theme.accent if self.taken else theme.border);
            for step in [3, 7, 11] {
                canvas.line(grip.right() - step, grip.bottom() - 2, grip.right() - 2, grip.bottom() - step, theme.dim);
            }
        }
        canvas.clip(self.clip);
    }

    """Keep it where it may go (on the stage, or within its bounds), and no
    smaller than it may be."""
    def settle(stage: Stage) {
        room = self.bounds if self.bounds.w > 0 and self.bounds.h > 0 else Rect(x=0, y=0, w=stage.width, h=stage.height);
        wide = max(self.least_wide, min(self.area.w, room.w));
        tall = max(self.least_tall, min(self.area.h, room.h));
        self.area = Rect(
            x=max(room.x, min(self.area.x, room.right() - wide)),
            y=max(room.y, min(self.area.y, room.bottom() - tall)),
            w=wide,
            h=tall
        );
    }

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "press" and event.button == 0 {
            self.taken = "";
            if self.corner().holds(event.x, event.y) {
                self.taken = "size";
            } elif event.y < self.area.y + self.bar and not self.cross().holds(event.x, event.y) {
                self.taken = "move";
            }
            return True;
        }
        if event.kind == "drag" {
            if self.taken == "move" {
                self.area = Rect(x=self.area.x + event.dx, y=self.area.y + event.dy, w=self.area.w, h=self.area.h);
                self.settle(stage);
            } elif self.taken == "size" {
                self.area = Rect(
                    x=self.area.x,
                    y=self.area.y,
                    w=max(self.least_wide, self.area.w + event.dx),
                    h=max(self.least_tall, self.area.h + event.dy)
                );
                self.settle(stage);
            }
            return True;
        }
        if event.kind == "release" {
            self.taken = "";
            return True;
        }
        if event.kind == "click" and event.button == 0 {
            if self.cross().holds(event.x, event.y) {
                stage.emit(self.command);
            }
            return True;
        }
        return event.kind in ["press", "double", "wheel"];
    }

    def solid -> bool {
        return True;
    }
}
