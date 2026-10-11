"""The studio's interface is a graph.

A Stage holds layers; each layer is a tree of Widget nodes joined by Child
edges. Every frame three walkers travel it: Arrange lays the widgets out,
Paint draws them depth first, and Pick finds the widget under the pointer.
Input reaches a widget on a Deliver walker that climbs the Child edges
backwards until some widget takes the event.

Widgets ask for things by emitting console commands on the Stage, so anything
a click can do can also be typed, bound to a key or scripted."""
import from .canvas { Canvas, Rect, Ink }
import from .input { UiInput }

edge Child: Widget --> Widget {}

edge Layer: Stage --> Widget {}

"""Something that happened to a widget: press, release, click, double, drag,
wheel, key, text, focus or blur. Positions are screen units."""
obj UiEvent {
    has kind: str,
        x: int = 0,
        y: int = 0,
        dx: int = 0,
        dy: int = 0,
        button: int = 0,
        wheel: float = 0.0,
        key: str = "",
        text: str = "",
        shift: bool = False,
        ctrl: bool = False,
        alt: bool = False;
}

node Widget {
    has name: str = "",
        area: Rect = Rect(),
        # The part of the area its parents leave visible.
        clip: Rect = Rect(),
        shown: bool = True,
        enabled: bool = True,
        # Length along the parent's axis: `size` when set, else what wanted()
        # answers; `grow` shares out what the fixed widgets leave over.
        size: int = 0,
        grow: int = 0,
        # Whether that axis runs across (kept by adopt and Arrange).
        along: bool = False,
        # Shown in the hint bar while the pointer is over the widget.
        hint: str = "",
        hovered: bool = False,
        held: bool = False,
        focused: bool = False,
        # As a layer: `modal` keeps the pointer from the layers beneath, and a
        # `transient` layer closes when a press lands outside it.
        modal: bool = False,
        transient: bool = False;

    def kids -> list[Widget] {
        return [self->:Child:->][?:Widget];
    }

    def parent -> Widget | None {
        above = [self<-:Child:<-][?:Widget];
        return above[0] if above else None;
    }

    def adopt(kid: Widget) -> Widget {
        self +>:Child:+> kid;
        kid.along = self.lays_across();
        return kid;
    }

    """Whether children are laid out side by side."""
    def lays_across -> bool {
        return False;
    }

    """The fixed length asked for along an axis: `size` on the parent's
    axis, nothing on the other."""
    def fixed(across: bool) -> int {
        return self.size if across == self.along else 0;
    }

    def orphan(kid: Widget) {
        self del->:Child:-> kid;
    }

    """Let every child go."""
    def clear {
        for kid in self.kids() {
            self del->:Child:-> kid;
        }
    }

    """The first widget named `name` in this subtree."""
    def find(name: str) -> Widget | None {
        search = self spawn FindWidget(name=name);
        return search.found;
    }

    """The length this widget asks for: its width when `across`, else its
    height."""
    def wanted(canvas: Canvas, across: bool) -> int {
        return self.fixed(across);
    }

    """Give every child its area."""
    def place(canvas: Canvas) {}

    def draw(canvas: Canvas) {}

    """Draw over the children."""
    def draw_over(canvas: Canvas) {}

    """Take an event. True stops it climbing to the parent."""
    def on(event: UiEvent, stage: Stage) -> bool {
        return False;
    }

    """Follow the pointer between events (which row it is over): called
    each frame by whoever owns the widget."""
    def track(stage: Stage) {}

    """Whether the pointer lands on this widget rather than passing through."""
    def solid -> bool {
        return False;
    }

    """Whether a press gives this widget the keyboard."""
    def focusable -> bool {
        return False;
    }
}

"""Lay a tree out: each widget places its children, which are clipped to what
is visible of their parent."""
walker Arrange {
    has canvas: Canvas;

    can lay with Widget entry {
        if not here.shown {
            return;
        }
        across = here.lays_across();
        for kid in [here->:Child:->][?:Widget] {
            kid.along = across;
        }
        here.place(self.canvas);
        visible = here.area.within(here.clip);
        for kid in [here->:Child:->][?:Widget] {
            kid.clip = kid.area.within(visible);
        }
        visit :0: [here->:Child:->];
    }
}

"""Draw a tree depth first, so children cover their parent and later siblings
cover earlier ones. A widget draws again as the walker leaves it, over its
children."""
walker Paint {
    has canvas: Canvas,
        drawn: int = 0;

    can under with Widget entry {
        if not here.shown or here.clip.w <= 0 or here.clip.h <= 0 {
            return;
        }
        self.canvas.clip(here.clip);
        here.draw(self.canvas);
        self.drawn += 1;
        visit :0: [here->:Child:->];
    }

    can over with Widget exit {
        if here.shown and here.clip.w > 0 and here.clip.h > 0 {
            self.canvas.clip(here.clip);
            here.draw_over(self.canvas);
        }
    }
}

"""Find the solid widget drawn last under a point: the walk follows the paint
order, so the last one it meets is the one on top."""
walker Pick {
    has x: int,
        y: int,
        found: Widget | None = None;

    can probe with Widget entry {
        if not here.shown or not here.clip.holds(self.x, self.y) {
            return;
        }
        if here.enabled and here.solid() {
            self.found = here;
        }
        visit :0: [here->:Child:->];
    }
}

"""Carry an event up from a widget through its parents until one takes it."""
walker Deliver {
    has event: UiEvent,
        stage: Stage,
        taken: bool = False;

    can offer with Widget entry {
        if here.enabled and here.on(self.event, self.stage) {
            self.taken = True;
            disengage;
        }
        visit [here<-:Child:<-];
    }
}

walker FindWidget {
    has name: str,
        found: Widget | None = None;

    can look with Widget entry {
        if here.name == self.name {
            self.found = here;
            disengage;
        }
        visit :0: [here->:Child:->];
    }
}

"""The interface: its layers from the bottom up, where the pointer is, which
widget holds the pointer or the keyboard, and the commands widgets asked for
this frame."""
node Stage {
    has canvas: Canvas,
        width: int = 0,
        height: int = 0,
        hover: Widget | None = None,
        held: Widget | None = None,
        focus: Widget | None = None,
        commands: list[str] = [],
        # Keys and text no widget took: the studio's shortcuts.
        loose_keys: list[str] = [],
        loose_text: str = "",
        input: UiInput = UiInput(),
        clock: float = 0.0;

    def layers -> list[Widget] {
        return [self->:Layer:->][?:Widget];
    }

    """Add a layer above the others."""
    def open(layer: Widget) {
        self +>:Layer:+> layer;
    }

    def close(layer: Widget) {
        if layer in self.layers() {
            self del->:Layer:-> layer;
        }
        # Forget pointers into the layer that left.
        target = self.hover;
        if target is not None {
            target.hovered = False;
        }
        self.hover = None;
        if self.held is not None {
            self.release_hold();
        }
    }

    """Close every transient layer (menus, lists)."""
    def dismiss {
        for layer in self.layers() {
            if layer.transient {
                self.close(layer);
            }
        }
    }

    """Ask for a console command."""
    def emit(command: str) {
        if command {
            self.commands.append(command);
        }
    }

    def take_commands -> list[str] {
        asked = self.commands;
        self.commands = [];
        return asked;
    }

    """Give the keyboard to a widget, or to none."""
    def focus_on(widget: Widget | None) {
        old = self.focus;
        if old is widget {
            return;
        }
        if old is not None {
            old.focused = False;
            old.on(UiEvent(kind="blur"), self);
        }
        self.focus = widget;
        if widget is not None {
            widget.focused = True;
            widget.on(UiEvent(kind="focus"), self);
        }
    }

    def release_hold {
        target = self.held;
        if target is not None {
            target.held = False;
        }
        self.held = None;
    }

    """The hint of the widget under the pointer, or of the nearest parent
    that has one."""
    def hint -> str {
        target = self.hover;
        while target is not None {
            if target.hint {
                return target.hint;
            }
            target = target.parent();
        }
        return "";
    }

    """The solid widget under a point, looking through the layers from the
    top; a modal layer hides the ones beneath it."""
    def pick(x: int, y: int) -> Widget | None {
        stack = self.layers();
        for i in range(len(stack) - 1, -1, -1) {
            probe = stack[i] spawn Pick(x=x, y=y);
            if probe.found is not None {
                return probe.found;
            }
            if stack[i].modal {
                return None;
            }
        }
        return None;
    }

    def arrange {
        screen = Rect(x=0, y=0, w=self.width, h=self.height);
        stack = self.layers();
        for i in range(len(stack)) {
            layer = stack[i];
            if i == 0 {
                layer.area = screen;
            }
            layer.clip = layer.area.within(screen);
            layer spawn Arrange(canvas=self.canvas);
        }
    }

    def send(target: Widget, event: UiEvent) -> bool {
        delivery = target spawn Deliver(event=event, stage=self);
        return delivery.taken;
    }

    """Run a frame: lay the layers out and route the frame's input."""
    def frame(input: UiInput, width: int, height: int, dt: float) {
        self.input = input;
        self.width = width;
        self.height = height;
        self.clock += dt;
        self.canvas.clock = self.clock;
        self.loose_keys = [];
        self.loose_text = "";
        self.arrange();

        under = self.pick(input.x, input.y);
        old = self.hover;
        if under is not old {
            if old is not None {
                old.hovered = False;
            }
            if under is not None {
                under.hovered = True;
            }
            self.hover = under;
        }

        for button in range(3) {
            if input.pressed[button] {
                # A press outside the transient layers closes them.
                for layer in self.layers() {
                    if layer.transient and not layer.area.holds(input.x, input.y) {
                        self.close(layer);
                    }
                }
                under = self.pick(input.x, input.y);
                self.hover = under;
                if under is not None {
                    under.hovered = True;
                }
                self.focus_on(under if under is not None and under.focusable() else None);
                if under is not None {
                    self.held = under;
                    under.held = True;
                    self.send(
                        under,
                        self.pointer_event("double" if input.double and button == 0 else "press", button)
                    );
                }
            }
        }
        holder = self.held;
        if holder is not None and (input.dx != 0 or input.dy != 0) {
            self.send(holder, self.pointer_event("drag", 0));
        }
        for button in range(3) {
            if input.released[button] {
                holder = self.held;
                if holder is not None {
                    self.send(holder, self.pointer_event("release", button));
                    if self.pick(input.x, input.y) is holder {
                        self.send(holder, self.pointer_event("click", button));
                    }
                    self.release_hold();
                }
            }
        }
        if input.wheel != 0.0 {
            target = self.hover;
            if target is not None {
                self.send(target, self.pointer_event("wheel", 0));
            }
        }
        for key in input.keys {
            if key.startswith("MOUSE") or key.startswith("MWHEEL") {
                continue;
            }
            event = UiEvent(
                kind="key", key=key, x=input.x, y=input.y, shift=input.shift, ctrl=input.ctrl, alt=input.alt
            );
            keyed = self.focus;
            if keyed is None or not self.send(keyed, event) {
                self.loose_keys.append(key);
            }
        }
        if input.text {
            keyed = self.focus;
            if keyed is None or not self.send(keyed, UiEvent(kind="text", text=input.text)) {
                self.loose_text = input.text;
            }
        }
    }

    def pointer_event(kind: str, button: int) -> UiEvent {
        input = self.input;
        return UiEvent(
            kind=kind,
            x=input.x,
            y=input.y,
            dx=input.dx,
            dy=input.dy,
            button=button,
            wheel=input.wheel,
            shift=input.shift,
            ctrl=input.ctrl,
            alt=input.alt
        );
    }

    """Draw every layer, bottom first. Answers how many widgets drew."""
    def paint -> int {
        drawn = 0;
        for layer in self.layers() {
            pass_over = layer spawn Paint(canvas=self.canvas);
            drawn += pass_over.drawn;
        }
        self.canvas.unclip();
        return drawn;
    }
}
