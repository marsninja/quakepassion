"""One frame of pointer and key input for the studio's interface.

A UiSource turns either the real mouse or a queue of scripted steps into a
UiInput. Scripted steps come from console commands (ui_move, ui_click,
ui_drag, ui_key, ui_type, ...), so a config file can drive the interface
exactly as a hand would, one step a frame, for validation runs."""
import from vendor.raylib {
    def GetMouseX -> i32;  def GetMouseY -> i32;  def IsMouseButtonDown(button: i32) -> bool;  def GetMouseWheelMove -> f32;
}

"""What the pointer and keys did this frame. `keys` are the key names that
went down or repeated (engine/input/keys.jac's names); `text` is what was
typed."""
obj UiInput {
    has x: int = 0,
        y: int = 0,
        dx: int = 0,
        dy: int = 0,
        wheel: float = 0.0,
        down: list[bool] = [False, False, False],
        pressed: list[bool] = [False, False, False],
        released: list[bool] = [False, False, False],
        double: bool = False,
        keys: list[str] = [],
        text: str = "",
        shift: bool = False,
        ctrl: bool = False,
        alt: bool = False;
}

"""One scripted step: move, down, up, double, wheel, key, type, shift, ctrl,
alt or idle."""
obj UiStep {
    has kind: str,
        x: int = 0,
        y: int = 0,
        button: int = 0,
        amount: float = 0.0,
        words: str = "";
}

"""Where the interface's input comes from. Once a step has been scripted the
real mouse is ignored for the rest of the run, so a validation run does not
depend on where the cursor happens to be."""
obj UiSource {
    has scripted: bool = False,
        steps: list[UiStep] = [],
        x: int = 0,
        y: int = 0,
        down: list[bool] = [False, False, False],
        shift: bool = False,
        ctrl: bool = False,
        alt: bool = False,
        # The last press, for double clicks: seconds and place.
        press_time: float = -10.0,
        press_x: int = 0,
        press_y: int = 0,
        clock: float = 0.0;

    def script(step: UiStep) {
        self.scripted = True;
        self.steps.append(step);
    }

    """Scripted steps not yet played."""
    def pending -> int {
        return len(self.steps);
    }

    """This frame's input. `keys`, `text` and the modifiers are the real
    keyboard's, used while nothing is scripted."""
    def read(
        dt: float, keys: list[str], text: str, shift: bool, ctrl: bool, alt: bool
    ) -> UiInput {
        self.clock += dt;
        frame = UiInput();
        was_down = list(self.down);
        old_x = self.x;
        old_y = self.y;
        if self.scripted {
            if self.steps {
                step = self.steps.pop(0);
                if step.kind in ["move", "down", "up", "double"] and (step.x >= 0 and step.y >= 0) {
                    self.x = step.x;
                    self.y = step.y;
                }
                if step.kind == "down" or step.kind == "double" {
                    self.down[step.button] = True;
                    frame.double = step.kind == "double";
                } elif step.kind == "up" {
                    self.down[step.button] = False;
                } elif step.kind == "wheel" {
                    frame.wheel = step.amount;
                } elif step.kind == "key" {
                    frame.keys = [step.words];
                } elif step.kind == "type" {
                    frame.text = step.words;
                } elif step.kind == "shift" {
                    self.shift = step.button != 0;
                } elif step.kind == "ctrl" {
                    self.ctrl = step.button != 0;
                } elif step.kind == "alt" {
                    self.alt = step.button != 0;
                }
            }
            frame.shift = self.shift;
            frame.ctrl = self.ctrl;
            frame.alt = self.alt;
        } else {
            self.x = int(GetMouseX());
            self.y = int(GetMouseY());
            for button in range(3) {
                self.down[button] = IsMouseButtonDown(i32(button));
            }
            frame.wheel = float(GetMouseWheelMove());
            frame.keys = keys;
            frame.text = text;
            frame.shift = shift;
            frame.ctrl = ctrl;
            frame.alt = alt;
        }
        frame.x = self.x;
        frame.y = self.y;
        frame.dx = self.x - old_x;
        frame.dy = self.y - old_y;
        frame.down = list(self.down);
        for button in range(3) {
            frame.pressed[button] = self.down[button] and not was_down[button];
            frame.released[button] = was_down[button] and not self.down[button];
        }
        if frame.pressed[0] and not self.scripted {
            near = abs(self.x - self.press_x) <= 4 and abs(self.y - self.press_y) <= 4;
            frame.double = near and self.clock - self.press_time < 0.4;
            # A third click starts over rather than doubling again.
            self.press_time = -10.0 if frame.double else self.clock;
            self.press_x = self.x;
            self.press_y = self.y;
        }
        return frame;
    }
}

"""Queue a click at a point: move there, press, release."""
def script_click(source: UiSource, x: int, y: int, button: int = 0, double: bool = False) {
    source.script(UiStep(kind="move", x=x, y=y));
    source.script(UiStep(kind="double" if double else "down", x=x, y=y, button=button));
    source.script(UiStep(kind="up", x=x, y=y, button=button));
}

"""Queue a drag from one point to another over `frames` frames."""
def script_drag(
    source: UiSource, x0: int, y0: int, x1: int, y1: int, button: int = 0, frames: int = 6
) {
    source.script(UiStep(kind="move", x=x0, y=y0));
    source.script(UiStep(kind="down", x=x0, y=y0, button=button));
    count = max(1, frames);
    for i in range(1, count + 1) {
        source.script(
            UiStep(
                kind="move",
                x=x0 + ((x1 - x0) * i) // count,
                y=y0 + ((y1 - y0) * i) // count
            )
        );
    }
    source.script(UiStep(kind="up", x=x1, y=y1, button=button));
}
