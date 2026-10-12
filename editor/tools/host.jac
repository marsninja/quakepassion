"""What a tool of the studio is, and what it may ask of the studio.

A tool lives in a module of its own and imports this module, never the
studio: a native build analyses again, from source, everything a changed
module imports, so a tool that imported the studio would cost as much to
rebuild as the studio does. The studio hands each tool a ToolHost and
implements it; a tool keeps its own state.

The methods are abstract so that what is defined in other modules is reached
through the bases (see Workbench)."""
import from engine.math.vec3 { Vec3 }
import from engine.world.bot_routes { NavMesh }
import from editor.document.scene { Scene }
import from editor.ui.canvas { Ink }

"""What the studio does for its tools."""
obj ToolHost {
    """Say something: in the console, and in the status bar."""
    def say(message: str) abst;

    """The level's navigation: what was baked in the studio, or a shipped
    arena's own. None when there is neither."""
    def navigation -> NavMesh | None abst;

    """A number that changes when the baked navigation does."""
    def navigation_mark -> int abst;

    """Draw a line in the level view being drawn."""
    def line(start: Vec3, finish: Vec3, color: Ink) abst;
}

"""A tool: the studio asks its tools each command before its own, lets them
draw in the level views, and takes their lines of the dump and settings."""
obj StudioTool {
    """The commands it answers that the studio does not already declare:
    name, usage, description."""
    def commands -> list[tuple[str, str, str]] abst;

    """Run a command if it is this tool's. False when it is not."""
    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool abst;

    """Draw in a level view as its camera sees, through the walls."""
    def draw_through(host: ToolHost, scene: Scene) abst;

    """Its lines of the dump, each beginning "studio: "; none when it has
    nothing to say."""
    def dump_lines(host: ToolHost, scene: Scene) -> list[str] abst;

    """The commands that would set it again as it stands, for the settings."""
    def settings_lines(host: ToolHost) -> list[str] abst;
}
