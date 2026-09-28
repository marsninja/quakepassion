"""Input sampling. The only place (with keys.jac) that reads raylib input state;
everything downstream consumes an Intent.

Keys and mouse buttons run the commands bound to them (keys.jac). The input
layer owns the button commands (+forward, +attack, ...) and the one-shot ones
that ride in the move (impulse, weapon, weapnext, invuse, centerview, ...),
and each frame turns the buttons, the mouse and the input cvars into an Intent
as CL_BaseMove, CL_AdjustAngles and IN_MouseMove built a usercmd.

Mouse-look follows the raylib_shooter's battle-tested pattern for quirky
platforms (WSLg especially): the cursor starts free and is captured on a
click; deltas come from absolute position diffs with a warmup period and a
spike clamp, not GetMouseDelta.

Native pathway: raylib bound through the C-FFI by logical name from the
staged sibling library (see renderer.jac for the linking note).

Function bodies live in impl/input.impl.jac."""

import from vendor.raylib {
    def IsKeyPressed(key: i32) -> bool;  def GetMouseWheelMove -> f32;  def IsMouseButtonPressed(
        button: i32
    ) -> bool;  def GetMouseX -> i32;  def GetMouseY -> i32;  def DisableCursor -> None;  def EnableCursor -> None;
}

import from ..math.vec3 { Vec3 }
import from ..console.cvar { Cvar, CVAR_ARCHIVE }
import from ..console.shell { Shell }


"""One frame's usercmd: movement as fractions of the running speed (1.0 runs,
0.5 walks), view turns in radians, and this frame's one-shot requests."""
obj Intent {
    has move: Vec3 = Vec3(),
        look_yaw: float = 0.0,
        look_pitch: float = 0.0,
        jump: bool = False,
        jump_held: bool = False,
        crouch: bool = False,
        fire: bool = False,
        weapon: int = 0,
        weapon_step: int = 0,
        use_item: bool = False,
        use_kind: str = "",
        next_item: bool = False,
        prev_item: bool = False,
        scores: bool = False,
        help: bool = False,
        inventory: bool = False,
        center_view: bool = False,
        impulse: int = 0;
}


obj MouseState {
    has captured: bool = False,
        warmup: int = 0,
        prev_x: float = 0.0,
        prev_y: float = 0.0;
}

glob SPIKE_LIMIT: float = 150.0;

glob _mouse: MouseState = MouseState();

edge Holds: Controls --> Button {}

"""kbutton_t: a button held by up to two keys (`holders`, by key name; "" for
the console), with the frame's state bits: 1 down, 2 went down, 4 went up."""
node Button {
    has name: str,
        holders: list[str] = [],
        state: int = 0;

    """KeyDown."""
    def press(holder: str);
    """KeyUp."""
    def release(holder: str);
    """CL_KeyState: how much of the frame the button was down (0.25 pressed and
    released, 0.5 pressed, 0.75 released and pressed again, 1.0 held)."""
    def fraction -> float;
    def held -> bool;
    """Down now or pressed at some point this frame (`state & 3`)."""
    def active -> bool;
    def went_down -> bool;
}

walker FindButton {
    has name: str,
        found: Button | None = None;

    can start with Controls entry;
    can check with Button entry;
}

"""Read every button's state for this frame's move (CL_KeyState, `state & 1`,
`state & 3`) and clear its frame impulses."""
walker ReadButtons {
    has fraction: dict[str, float] = {},
        held: dict[str, bool] = {},
        active: dict[str, bool] = {},
        went_down: dict[str, bool] = {};

    can start with Controls entry;
    can read with Button entry;
}

"""Let go of every button."""
walker ReleaseButtons {
    can start with Controls entry;
    can release with Button entry;
}

"""The cvars the input layer owns (cl_input.c, in_win.c)."""
obj InputCvars {
    has sensitivity: Cvar = Cvar(
            name="sensitivity",
            reset_text="5",
            kind="float",
            low=0.0,
            high=100.0,
            flags=CVAR_ARCHIVE,
            description="mouse speed"
        ),
        m_pitch: Cvar = Cvar(
            name="m_pitch",
            reset_text="0.022",
            kind="float",
            flags=CVAR_ARCHIVE,
            description="mouse pitch scale (negative inverts)"
        ),
        m_yaw: Cvar = Cvar(name="m_yaw", reset_text="0.022", kind="float", flags=CVAR_ARCHIVE),
        m_forward: Cvar = Cvar(name="m_forward", reset_text="1", kind="float", flags=CVAR_ARCHIVE),
        m_side: Cvar = Cvar(name="m_side", reset_text="0.8", kind="float", flags=CVAR_ARCHIVE),
        freelook: Cvar = Cvar(
            name="freelook",
            reset_text="1",
            kind="bool",
            flags=CVAR_ARCHIVE,
            aliases=["cl_freelook"],
            description="the mouse always looks up and down"
        ),
        lookstrafe: Cvar = Cvar(name="lookstrafe", reset_text="0", kind="bool", flags=CVAR_ARCHIVE),
        forward_speed: Cvar = Cvar(
            name="cl_forwardspeed", reset_text="200", kind="float", low=0.0, high=10000.0, flags=CVAR_ARCHIVE
        ),
        back_speed: Cvar = Cvar(
            name="cl_backspeed", reset_text="200", kind="float", low=0.0, high=10000.0, flags=CVAR_ARCHIVE
        ),
        side_speed: Cvar = Cvar(
            name="cl_sidespeed", reset_text="350", kind="float", low=0.0, high=10000.0, flags=CVAR_ARCHIVE
        ),
        up_speed: Cvar = Cvar(name="cl_upspeed", reset_text="200", kind="float", low=0.0, high=10000.0),
        speed_key: Cvar = Cvar(name="cl_movespeedkey", reset_text="2", kind="float", low=0.1, high=10.0),
        yaw_speed: Cvar = Cvar(name="cl_yawspeed", reset_text="140", kind="float"),
        pitch_speed: Cvar = Cvar(name="cl_pitchspeed", reset_text="150", kind="float"),
        angle_speed_key: Cvar = Cvar(name="cl_anglespeedkey", reset_text="1.5", kind="float"),
        run: Cvar = Cvar(
            name="cl_run",
            reset_text="1",
            kind="bool",
            flags=CVAR_ARCHIVE,
            description="always run (the speed key walks)"
        );
}

"""The buttons the binds press (CL_InitInput's in_* kbuttons; Q3's +scores and
+button2)."""
glob BUTTON_NAMES: list[str] = [
    "forward",
    "back",
    "moveleft",
    "moveright",
    "left",
    "right",
    "lookup",
    "lookdown",
    "moveup",
    "movedown",
    "speed",
    "strafe",
    "attack",
    "jump",
    "use",
    "klook",
    "mlook",
    "showscores",
    "scores",
    "button2"
];

"""The input layer: its buttons, its cvars and the one-shot requests the
commands leave for the next move."""
node Controls {
    has cvars: InputCvars = InputCvars(),
        pending: Intent = Intent(),
        booted: bool = False;

    """Create the buttons and declare the input commands and cvars."""
    def declare(shell: Shell);
    """Run one of the input layer's commands."""
    def command(shell: Shell, args: list[str]);
    def button(name: str) -> Button | None;
    """This frame's Intent from the buttons, the mouse and the pending
    requests; the frame's impulses and requests are then cleared."""
    def sample(dt: float) -> Intent;
    """Let go of every button."""
    def release_all;
}


def mouse_captured() -> bool;
def _capture();
def _release();
"""The captured mouse's movement since the last frame, in pixels."""
def mouse_motion() -> tuple[float, float];
