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
import from engine.formats.bsp { Texture }

"""A box a tool shows floating over the studio: words to edit, with their
lines numbered, what the tool has to say of them beside, and buttons. When
the words are let go (Ctrl+Enter, a press elsewhere) the studio runs
`order`; the tool then asks for the words as they stand."""
obj PanelSpec {
    has title: str = "",
        text: str = "",
        order: str = "",
        notes: list[str] = [],
        buttons: list[tuple[str, str]] = [],
        # Bars to drag: what each is called, how far along it is from 0 to
        # 1, and the command run with the new value when it is let go.
        # With no `order` the box has no words to edit, and the bars and
        # notes are all of it.
        bars: list[tuple[str, float, str]] = [],
        # Where the box first stands: its width and height, and whether
        # against the right edge (beside the view) rather than in the middle.
        # None but the defaults when zero.
        wide: int = 0,
        tall: int = 0,
        right: bool = False;
}

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

    """A material's picture with its colours in `rgba`, four bytes a texel,
    however the material is kept (a game's texture, an image file of the
    project's). None when nothing holds that material."""
    def picture(material: str) -> Texture | None abst;

    """A game's 256 colours, 768 bytes; nothing when its archives are not here."""
    def palette(game: str) -> bytes abst;

    """Where files of a kind are kept: "textures" for the image files that
    are materials, "scenes" for saved scenes, "scripts" for a project's
    scripts, "" for the open project's own folder ("" back when there is
    none)."""
    def folder(kind: str) -> str abst;

    """A file out of a game's archives, or None; and every file's name there."""
    def read_file(game: str, name: str) -> bytes | None abst;
    def file_names(game: str) -> list[str] abst;

    """Files have been written where the studio lists them: list them again."""
    def files_changed abst;

    """Run one of the studio's own commands, as its words; and the scene
    being edited now (a command may have changed which that is)."""
    def run(words: list[str]) abst;
    def scene_now -> Scene | None abst;

    """The materials the browser lists now; the row of frames a material
    is one of (itself alone when it does not move); and whether a
    material is drawn warping, as the games draw their liquids."""
    def materials_shown -> list[str] abst;
    def frames_of(material: str) -> list[str] abst;
    def warps(material: str) -> bool abst;

    """Show a picture in the browser in place of a material's own: `rgba`
    is four bytes a texel."""
    def show_picture(material: str, width: int, height: int, rgba: bytes) abst;

    """Show a box of the tool's own under a name (or show it anew), give
    the words in it as they stand ("" when it is not open), and close it."""
    def panel(key: str, spec: PanelSpec) abst;
    def panel_text(key: str) -> str abst;
    def panel_close(key: str) abst;

    """Whether a game is being played from the studio, and the names that
    have fired in it so far, in order."""
    def playing -> bool abst;
    def fired_log -> list[str] abst;
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

    """A frame of the studio has passed: `dt` seconds of it."""
    def tick(host: ToolHost, dt: float) abst;

    """Its lines of the dump, each beginning "studio: "; none when it has
    nothing to say."""
    def dump_lines(host: ToolHost, scene: Scene) -> list[str] abst;

    """The commands that would set it again as it stands, for the settings."""
    def settings_lines(host: ToolHost) -> list[str] abst;
}
