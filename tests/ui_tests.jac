import from editor.ui.canvas { TraceCanvas, Rect, ink }
import from editor.ui.input { UiInput, UiSource, UiStep, script_click, script_drag }
import from editor.ui.widget { Widget, Stage, UiEvent }
import from editor.ui.widgets {
    Box,
    Label,
    Spacer,
    PushButton,
    Check,
    TextField,
    Scroll,
    Splitter,
    TreeView,
    TreeRow,
    Tabs,
    MenuBar,
    MenuItem,
    ViewArea,
    Gallery,
    Tile,
    GraphView,
    GraphNode,
    GraphLink,
    Dropdown,
    Swatch,
    MenuPopup,
    Picture
}

"""Run frames until the scripted steps are played, plus one to settle."""
def play(stage: Stage, source: UiSource, width: int = 800, height: int = 600) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
    }
    stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
}

def staged(top: Widget, canvas: TraceCanvas | None = None) -> Stage {
    stage = Stage(canvas=canvas if canvas is not None else TraceCanvas());
    stage.open(top);
    return stage;
}

test "rectangles clip, inset and test points" {
    a = Rect(x=10, y=10, w=100, h=50);
    assert a.holds(10, 10) and a.holds(109, 59) and not a.holds(110, 10) and not a.holds(10, 60);
    assert a.inset(4).same(Rect(x=14, y=14, w=92, h=42));
    assert a.within(Rect(x=50, y=0, w=200, h=30)).same(Rect(x=50, y=10, w=60, h=20));
    assert a.within(Rect(x=500, y=500, w=10, h=10)).w == 0;
    shade = ink(0xff7a18);
    assert shade.r == 255 and shade.g == 122 and shade.b == 24 and shade.a == 255;
}

test "a box gives fixed children their length and shares the rest among the growing" {
    top = Box(across=True, pad=10, gap=5);
    left = Widget(size=100);
    top.adopt(left);
    middle = Widget(grow=1);
    top.adopt(middle);
    right = Widget(grow=3);
    top.adopt(right);
    hidden = Widget(size=500, shown=False);
    top.adopt(hidden);
    stage = staged(top);
    stage.frame(UiInput(), 800, 600, 0.016);
    assert top.area.same(Rect(x=0, y=0, w=800, h=600));
    assert left.area.same(Rect(x=10, y=10, w=100, h=580));
    # 800 - 20 padding - 10 gaps - 100 fixed = 670, shared 1:3 with the
    # remainder going to the last.
    assert middle.area.x == 115 and middle.area.w == 167;
    assert right.area.x == 287 and right.area.w == 503 and right.area.right() == 790;
    assert hidden.area.w == 0;
}

test "a column stacks its children and nested boxes ask for what they hold" {
    top = Box();
    bar = Box(across=True, pad=2, gap=4);
    top.adopt(bar);
    bar.adopt(Label(text="File"));
    bar.adopt(Label(text="Edit"));
    body = Widget(grow=1);
    top.adopt(body);
    stage = staged(top);
    stage.frame(UiInput(), 400, 300, 0.016);
    canvas = stage.canvas;
    # A row of labels is one row tall plus its padding.
    assert bar.area.h == canvas.theme.row + 4;
    assert body.area.y == bar.area.h and body.area.h == 300 - bar.area.h;
    assert bar.wanted(canvas, True) == 2 * canvas.text_width("File") + 4 + 4;
}

test "the pointer lands on the widget drawn last under it" {
    top = Box(fill="panel");
    first = PushButton(name="first", text="One", size=40);
    top.adopt(first);
    second = PushButton(name="second", text="Two", size=40);
    top.adopt(second);
    stage = staged(top);
    stage.frame(UiInput(), 300, 200, 0.016);
    assert stage.pick(10, 10) is first;
    assert stage.pick(10, 50) is second;
    assert stage.pick(10, 150) is top;
    assert stage.pick(1000, 10) is None;
    assert top.find("second") is second and top.find("third") is None;
}

test "a click on a button asks for its command; a press dragged off does not" {
    top = Box();
    button = PushButton(text="Play", command="ed_play", size=30);
    top.adopt(button);
    stage = staged(top);
    source = UiSource();
    script_click(source, 20, 10);
    play(stage, source);
    assert stage.take_commands() == ["ed_play"];
    assert not button.held;
    script_drag(source, 20, 10, 20, 300);
    play(stage, source);
    assert stage.take_commands() == [];
}

test "a disabled button takes no click" {
    top = Box();
    top.adopt(PushButton(text="Save", command="ed_save", size=30, enabled=False));
    stage = staged(top);
    source = UiSource();
    script_click(source, 20, 10);
    play(stage, source);
    assert stage.take_commands() == [];
}

test "a check box flips and reports its state" {
    top = Box();
    check = Check(text="Snap", command="ed_snap");
    top.adopt(check);
    stage = staged(top);
    source = UiSource();
    script_click(source, 8, 8);
    play(stage, source);
    script_click(source, 8, 8);
    play(stage, source);
    assert stage.take_commands() == ["ed_snap 1", "ed_snap 0"];
    assert not check.on_now;
}

test "a text field edits its draft and commits on Enter" {
    top = Box();
    field = TextField(value="100", command="ed_set health");
    top.adopt(field);
    stage = staged(top);
    source = UiSource();
    script_click(source, 300, 10);
    play(stage, source);
    assert stage.focus is field and field.editing and field.cursor == 3;
    source.script(UiStep(kind="key", words="BACKSPACE"));
    source.script(UiStep(kind="type", words="5"));
    source.script(UiStep(kind="key", words="HOME"));
    source.script(UiStep(kind="type", words="2"));
    play(stage, source);
    assert field.draft == "2105" and field.value == "100";
    source.script(UiStep(kind="key", words="ENTER"));
    play(stage, source);
    assert field.value == "2105" and stage.focus is None;
    assert stage.take_commands() == ["ed_set health \"2105\""];
}

test "Escape puts a text field's old text back, and leaving it commits" {
    top = Box();
    field = TextField(value="door", command="ed_set targetname", size=30);
    top.adopt(field);
    other = TextField(value="", command="ed_set target", size=30);
    top.adopt(other);
    stage = staged(top);
    source = UiSource();
    script_click(source, 300, 10);
    source.script(UiStep(kind="type", words="way"));
    source.script(UiStep(kind="key", words="ESCAPE"));
    play(stage, source);
    assert field.value == "door" and stage.take_commands() == [];
    script_click(source, 300, 10);
    source.script(UiStep(kind="type", words="2"));
    script_click(source, 300, 45);
    play(stage, source);
    assert stage.focus is other;
    assert field.value == "door2";
    assert stage.take_commands() == ["ed_set targetname \"door2\""];
}

test "a text field selects, copies, cuts and pastes" {
    top = Box();
    field = TextField(value="monster_ogre");
    top.adopt(field);
    stage = staged(top);
    source = UiSource();
    script_click(source, 300, 10, double=True);
    play(stage, source);
    assert field.anchor == 0 and field.cursor == 12;
    source.script(UiStep(kind="ctrl", button=1));
    source.script(UiStep(kind="key", words="x"));
    play(stage, source);
    assert field.draft == "" and stage.canvas.copied() == "monster_ogre";
    source.script(UiStep(kind="key", words="v"));
    source.script(UiStep(kind="key", words="v"));
    source.script(UiStep(kind="ctrl", button=0));
    play(stage, source);
    assert field.draft == "monster_ogremonster_ogre";
}

test "keys no field takes are left for the studio's shortcuts" {
    top = Box();
    field = TextField(value="");
    top.adopt(field);
    stage = staged(top);
    stage.frame(UiInput(keys=["DEL"]), 300, 200, 0.016);
    assert stage.loose_keys == ["DEL"];
    stage.focus_on(field);
    stage.frame(UiInput(keys=["DEL", "F5", "a"], text="a"), 300, 200, 0.016);
    # The field edits with Delete and swallows the typed letter; F5 passes.
    assert stage.loose_keys == ["F5"] and stage.loose_text == "" and field.draft == "a";
}

test "a tree asks to pick, add to, toggle and open its rows" {
    top = Box();
    tree = TreeView(pick="ed_select", toggle="ed_fold", open_command="ed_focus", grow=1);
    top.adopt(tree);
    tree.rows = [
        TreeRow(key="0", text="worldspawn", branch=True, opened=True),
        TreeRow(key="7", text="func_door", depth=1),
        TreeRow(key="9", text="light", depth=1)
    ];
    stage = staged(top);
    source = UiSource();
    script_click(source, 100, 30);
    source.script(UiStep(kind="shift", button=1));
    script_click(source, 100, 50);
    source.script(UiStep(kind="shift", button=0));
    script_click(source, 8, 10);
    script_click(source, 100, 50, double=True);
    script_click(source, 100, 300);
    play(stage, source);
    assert stage.take_commands() == [
        "ed_select \"7\"",
        "ed_select \"9\" add",
        "ed_fold \"0\"",
        "ed_focus \"9\"",
        "ed_select"
    ];
}

test "a long tree scrolls by the wheel and draws only the rows in view" {
    top = Box();
    tree = TreeView(grow=1);
    top.adopt(tree);
    tree.rows = [TreeRow(key=str(i), text="entity " + str(i)) for i in range(500)];
    canvas = TraceCanvas();
    stage = staged(top, canvas);
    source = UiSource();
    source.script(UiStep(kind="move", x=50, y=50));
    source.script(UiStep(kind="wheel", amount=-2.0));
    play(stage, source, 300, 200);
    assert tree.offset == 120;
    stage.paint();
    drawn = [word for word in canvas.words() if word.startswith("entity ")];
    assert drawn[0] == "entity 6" and len(drawn) == 11;
    tree.reveal(499);
    assert tree.offset == 500 * 20 - 200;
}

test "a scroll window moves its child and clips it" {
    top = Box();
    window = Scroll(grow=1);
    top.adopt(window);
    column = Box();
    window.adopt(column);
    rows = [column.adopt(PushButton(text="row " + str(i), command="row " + str(i))) for i in range(40)];
    stage = staged(top);
    source = UiSource();
    source.script(UiStep(kind="move", x=50, y=50));
    play(stage, source, 300, 200);
    assert window.tall == 40 * 24 and window.reach() == 760;
    assert rows[39].clip.h == 0 and rows[0].clip.h == 24;
    source.script(UiStep(kind="wheel", amount=-100.0));
    play(stage, source, 300, 200);
    assert window.offset == 760;
    assert rows[39].area.bottom() == 200 and rows[39].clip.h == 24 and rows[0].clip.h == 0;
    # The row scrolled out of view cannot be clicked through the window's edge.
    script_click(source, 50, 190);
    play(stage, source, 300, 200);
    assert stage.take_commands() == ["row 39"];
}

test "a splitter drags the length of the panel beside it within its limits" {
    top = Box(across=True);
    side = Box(size=200, fill="panel");
    top.adopt(side);
    bar = Splitter(target=side, low=100, high=400);
    top.adopt(bar);
    top.adopt(Widget(grow=1));
    stage = staged(top);
    source = UiSource();
    script_drag(source, 202, 100, 262, 100);
    play(stage, source);
    assert side.size == 260 and bar.area.x == 260;
    script_drag(source, 262, 100, 20, 100);
    play(stage, source);
    assert side.size == 100;
}

test "tabs show one page and switch on a click" {
    top = Box();
    tabs = Tabs(titles=["Scene", "Assets"], command="ed_tab", grow=1);
    top.adopt(tabs);
    scene = Widget();
    tabs.adopt(scene);
    assets = Widget();
    tabs.adopt(assets);
    stage = staged(top);
    stage.frame(UiInput(), 400, 300, 0.016);
    assert scene.shown and not assets.shown and scene.area.y == 24;
    source = UiSource();
    script_click(source, tabs.title_area(stage.canvas, 1).x + 5, 10);
    play(stage, source, 400, 300);
    assert assets.shown and not scene.shown;
    assert stage.take_commands() == ["ed_tab 1"];
}

test "a menu opens as a layer, runs its command and closes" {
    top = Box();
    bar = MenuBar(
        titles=["File", "Edit"],
        menus=[
            [MenuItem(text="Save", command="ed_save", keys="Ctrl+S"), MenuItem(rule=True), MenuItem(text="Quit", command="quit")],
            [MenuItem(text="Undo", command="ed_undo"), MenuItem(text="Redo", command="ed_redo", enabled=False)]
        ]
    );
    top.adopt(bar);
    body = PushButton(text="under", command="under", grow=1);
    top.adopt(body);
    stage = staged(top);
    source = UiSource();
    script_click(source, 20, 10);
    play(stage, source);
    bar.track(stage);
    assert bar.showing == 0 and len(stage.layers()) == 2;
    # Quit is the third line: 4 padding, a 22 row, a 7 rule.
    script_click(source, 30, 24 + 4 + 22 + 7 + 10);
    play(stage, source);
    bar.track(stage);
    assert stage.take_commands() == ["quit"];
    assert bar.showing == -1 and len(stage.layers()) == 1;
    # Moving across the bar with a menu open switches menus; a disabled
    # item does nothing; a press outside closes the menu.
    script_click(source, 20, 10);
    play(stage, source);
    source.script(UiStep(kind="move", x=bar.title_area(stage.canvas, 1).x + 4, y=10));
    play(stage, source);
    bar.track(stage);
    assert bar.showing == 1;
    edit_x = bar.title_area(stage.canvas, 1).x + 20;
    script_click(source, edit_x, 24 + 4 + 22 + 10);
    play(stage, source);
    bar.track(stage);
    assert stage.take_commands() == [] and bar.showing == 1;
    script_click(source, 400, 400);
    play(stage, source);
    bar.track(stage);
    assert bar.showing == -1 and len(stage.layers()) == 1;
    assert stage.take_commands() == ["under"];
    assert body.area.h > 0;
}

test "a view area keeps the events that reach it and takes the keyboard" {
    top = Box(across=True);
    top.adopt(Box(size=100, fill="panel"));
    view = ViewArea(grow=1);
    top.adopt(view);
    stage = staged(top);
    source = UiSource();
    script_drag(source, 300, 100, 340, 120, button=1, frames=2);
    source.script(UiStep(kind="wheel", amount=1.0));
    play(stage, source);
    kinds = [event.kind for event in view.take()];
    assert kinds == ["focus", "press", "drag", "drag", "release", "click", "wheel"];
    assert stage.focus is view;
    assert len(view.take()) == 0;
}

test "the hint under the pointer comes from the nearest widget that has one" {
    top = Box(hint="the window");
    panel = Box(fill="panel", grow=1);
    top.adopt(panel);
    panel.adopt(PushButton(text="Play", size=30, hint="Run the level from here"));
    panel.adopt(PushButton(text="Other", size=30));
    stage = staged(top);
    source = UiSource();
    source.script(UiStep(kind="move", x=10, y=10));
    play(stage, source);
    assert stage.hint() == "Run the level from here";
    source.script(UiStep(kind="move", x=10, y=40));
    play(stage, source);
    assert stage.hint() == "the window";
}

test "painting draws parents before children and clips each to what shows" {
    top = Box(fill="window");
    panel = Box(fill="panel", size=50);
    top.adopt(panel);
    panel.adopt(Label(text="hello"));
    canvas = TraceCanvas();
    stage = staged(top, canvas);
    stage.frame(UiInput(), 200, 100, 0.016);
    assert stage.paint() == 3;
    fills = [stroke.area for stroke in canvas.strokes if stroke.kind == "fill"];
    assert fills[0].same(Rect(x=0, y=0, w=200, h=100)) and fills[1].same(Rect(x=0, y=0, w=200, h=50));
    assert canvas.words() == ["hello"];
    assert canvas.strokes[-1].kind == "unclip";
}

test "a fixed size counts along the parent's axis only" {
    top = Box();
    row = Box(across=True, gap=4);
    top.adopt(row);
    name = Label(text="classname", size=96);
    row.adopt(name);
    field = TextField(value="func_door", grow=1);
    row.adopt(field);
    rest = Widget(grow=1);
    top.adopt(rest);
    stage = staged(top);
    stage.frame(UiInput(), 400, 300, 0.016);
    # The label is 96 wide and the row one row tall, not 96 tall.
    assert name.area.w == 96 and row.area.h == stage.canvas.theme.row;
    assert field.area.x == 100 and field.area.w == 300;
    assert rest.area.y == row.area.h;
}

test "a gallery lays tiles across, draws the kept pictures and picks by click" {
    canvas = TraceCanvas();
    canvas.keep_picture("brick", 2, 2, bytes(16));
    top = Box();
    wall = Gallery(pick="use", grow=1);
    top.adopt(wall);
    wall.tiles = [Tile(key="brick", text="brick"), Tile(key="moss", text="moss", picked=True)]
        + [Tile(key="t" + str(i), text="t" + str(i)) for i in range(40)];
    stage = staged(top, canvas);
    source = UiSource();
    play(stage, source, 400, 300);
    # (400 - 10 - 6) // 78 tiles across.
    assert wall.columns() == 4;
    assert wall.tile_area(0).same(Rect(x=6, y=6, w=72, h=72));
    assert wall.tile_area(5).same(Rect(x=84, y=100, w=72, h=72));
    assert wall.tile_at(90, 110) == 5 and wall.tile_at(80, 110) == -1;
    stage.paint();
    pictures = [stroke for stroke in canvas.strokes if stroke.kind == "picture"];
    assert len(pictures) == 1 and pictures[0].words == "brick";
    assert "moss" in canvas.words();
    script_click(source, 90, 20);
    play(stage, source, 400, 300);
    asked = stage.take_commands();
    assert len(asked) == 1 and asked[0] == "use \"moss\"";
    # The wheel scrolls a row at a time, no further than the last row.
    assert wall.reach() == 11 * 94 + 6 - 300;
    source.script(UiStep(kind="move", x=100, y=100));
    source.script(UiStep(kind="wheel", amount=-1.0));
    play(stage, source, 400, 300);
    assert wall.offset == 94;
    wall.reveal(41);
    assert wall.offset == wall.reach();
}

test "a graph view picks a box by a click, links two by a drag and slides its sheet" {
    canvas = TraceCanvas();
    top = Box();
    sheet = GraphView(pick="pick", open_command="look", link="join", grow=1, empty="Nothing fires anything.");
    top.adopt(sheet);
    stage = staged(top, canvas);
    source = UiSource();
    play(stage, source, 600, 400);
    stage.paint();
    assert "Nothing fires anything." in canvas.words();
    sheet.nodes = [
        GraphNode(key="7", text="func_button", column=0, row=0),
        GraphNode(key="9", text="func_door", note="door1", column=1, row=0, picked=True),
        GraphNode(key="12", text="light", column=1, row=1)
    ];
    sheet.links = [GraphLink(source="7", dest="9")];
    assert sheet.node_area(0).same(Rect(x=24, y=30, w=156, h=38));
    assert sheet.node_area(2).same(Rect(x=224, y=82, w=156, h=38));
    assert sheet.node_at(230, 90) == 2 and sheet.node_at(200, 90) == -1 and sheet.index_of("9") == 1;
    canvas.strokes = [];
    stage.paint();
    assert "func_door" in canvas.words() and "door1" in canvas.words();
    assert len([stroke for stroke in canvas.strokes if stroke.kind == "triangle"]) == 1;
    script_click(source, 240, 100);
    play(stage, source, 600, 400);
    asked = stage.take_commands();
    assert len(asked) == 1 and asked[0] == "pick \"12\"";
    # A drag from the button to the light asks for a link between them.
    script_drag(source, 60, 50, 300, 100);
    play(stage, source, 600, 400);
    asked = stage.take_commands();
    assert len(asked) == 1 and asked[0] == "join \"7\" \"12\"";
    # A click on the sheet picks nothing; a drag on it slides the boxes.
    script_click(source, 500, 300);
    play(stage, source, 600, 400);
    asked = stage.take_commands();
    assert len(asked) == 1 and asked[0] == "pick";
    script_drag(source, 500, 300, 460, 330);
    play(stage, source, 600, 400);
    assert sheet.slide_x == -40 and sheet.slide_y == 30 and len(stage.take_commands()) == 0;
    assert sheet.node_area(0).same(Rect(x=-16, y=60, w=156, h=38));
    script_click(source, 240, 100);
    source.script(UiStep(kind="idle"));
    play(stage, source, 600, 400);
    stage.take_commands();
    sheet.reveal(0);
    assert sheet.node_area(0).x == 24;
}

test "a dropdown opens its list under it and a choice runs that label's command" {
    canvas = TraceCanvas();
    top = Box();
    chooser = Dropdown(text="stone", labels=["silent", "stone", "machine"], commands=["set 0", "set 1", "set 2"]);
    top.adopt(chooser);
    top.adopt(Swatch(red=1.0, green=0.5, blue=0.0));
    stage = staged(top, canvas);
    source = UiSource();
    play(stage, source, 300, 200);
    stage.paint();
    assert "stone" in canvas.words();
    assert len(stage.layers()) == 1;
    script_click(source, 40, 10);
    play(stage, source, 300, 200);
    assert len(stage.layers()) == 2 and len(stage.take_commands()) == 0;
    popup = stage.layers()[1];
    assert popup.area.y == chooser.area.bottom() and popup.area.x == chooser.area.x;
    # The third line of the list.
    script_click(source, 40, popup.area.y + 4 + 22 * 2 + 10);
    play(stage, source, 300, 200);
    asked = stage.take_commands();
    assert len(asked) == 1 and asked[0] == "set 2" and len(stage.layers()) == 1;
    fills = [stroke for stroke in canvas.strokes if stroke.kind == "fill" and stroke.color.g == 127];
    assert len(fills) >= 1 and fills[0].color.r == 255 and fills[0].color.b == 0;
}

test "a picture is shown as large as fits, in proportion" {
    canvas = TraceCanvas();
    assert canvas.keep_encoded("wall", ".tga", bytes(32)) and not canvas.keep_encoded("none", ".tga", b"");
    assert canvas.picture_size("wall")[0] == 64 and canvas.picture_size("none")[0] == 0;
    top = Box();
    shown = Picture(key="wall", grow=1);
    top.adopt(shown);
    stage = staged(top, canvas);
    source = UiSource();
    play(stage, source, 408, 208);
    stage.paint();
    drawn = [stroke for stroke in canvas.strokes if stroke.kind == "picture"];
    # A square image in a wide space: as tall as the space, in its middle.
    assert len(drawn) == 1 and drawn[0].area.same(Rect(x=104, y=4, w=200, h=200));
    shown.key = "none";
    canvas.strokes = [];
    stage.paint();
    assert len([stroke for stroke in canvas.strokes if stroke.kind == "picture"]) == 0;
}
