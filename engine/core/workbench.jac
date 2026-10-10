"""A mode that takes the window from the game: the studio.

The engine knows only this interface. The editor package implements it and
main.jac attaches it to the App, so engine/ never imports editor/. While a
workbench is active the simulation stands still: the host hands it the
frame's keys, draws the level from each camera it asks for, and lets it draw
over the result."""
import from ..console.shell { Shell }
import from ..formats.bsp { Bsp }
import from ..math.vec3 { Vec3 }

"""One camera's view of the level, drawn into a rectangle of the window
(screen units). A positive `span` makes the view orthographic, that many
world units across the rectangle's height."""
obj SceneView {
    has x: int = 0,
        y: int = 0,
        width: int = 0,
        height: int = 0,
        eye: Vec3 = Vec3(),
        yaw: float = 0.0,
        pitch: float = 0.0,
        span: float = 0.0,
        # Draw every surface, ignoring the PVS (a camera outside the level
        # sees nothing otherwise).
        everything: bool = False;
}

"""The methods are abstract so that a workbench in another module is reached
through the base: a class nothing in its own module derives from or declares
abstract is laid out without a vtable, and calls on it bind to its own
bodies."""
obj Workbench {
    has active: bool = False;

    """Declare the workbench's commands and cvars. Its commands are owned by
    "studio", and come back through `command`."""
    def declare(shell: Shell) abst;

    """Run one of the workbench's commands."""
    def command(args: list[str]) abst;

    """One frame while active: the keys that went down or repeated, the text
    typed, and the modifiers held."""
    def frame(dt: float, keys: list[str], text: str, shift: bool, ctrl: bool, alt: bool) abst;

    """The cameras to draw the level from this frame."""
    def views -> list[SceneView] abst;

    """Draw into a view's scene, inside its 3D mode."""
    def draw_scene(view: SceneView) abst;

    """Draw over the finished views, in screen units."""
    def draw(width: int, height: int) abst;

    """A level's data when the workbench is where it comes from (a scene
    being edited), built afresh for each load; none for a level the game
    loads from its own files."""
    def build_level(game: str, name: str) -> Bsp | None abst;
}

"""No workbench: what an App has until one is attached."""
obj NoWorkbench(Workbench) {
    def declare(shell: Shell) {}

    def command(args: list[str]) {}

    def frame(dt: float, keys: list[str], text: str, shift: bool, ctrl: bool, alt: bool) {}

    def views -> list[SceneView] {
        return [];
    }

    def draw_scene(view: SceneView) {}

    def draw(width: int, height: int) {}

    def build_level(game: str, name: str) -> Bsp | None {
        return None;
    }
}
