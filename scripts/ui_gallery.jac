"""The studio's interface toolkit on its own: every widget in one window.

Builds in seconds (it needs none of the engine), so the toolkit can be
looked at and driven without loading a level:

    jac build scripts/ui_gallery.jac --native -o .jac/ui_gallery
    DYLD_LIBRARY_PATH=vendor .jac/ui_gallery

QP_UI_SCRIPT plays scripted input, one step a frame, then saves the window to
QP_UI_SHOT and exits. Steps are separated by ";": `move X Y`, `click X Y`,
`rclick X Y`, `double X Y`, `drag X0 Y0 X1 Y1`, `wheel N`, `key NAME`,
`type TEXT`, `idle N`."""
import os;
import from editor.ui.canvas { ScreenCanvas, Color }
import from editor.ui.input { UiSource, UiStep, script_click, script_drag }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets {
    Box,
    Label,
    Header,
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
    ViewArea
}
import from vendor.raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def CloseWindow -> None;  def BeginDrawing -> None;  def EndDrawing -> None;  def SetConfigFlags(
        flags: u32
    ) -> None;  def ClearBackground(color: Color) -> None;  def GetScreenWidth -> i32;  def GetScreenHeight -> i32;  def GetRenderWidth -> i32;  def GetRenderHeight -> i32;  def GetFrameTime -> f32;  def GetCharPressed -> i32;  def IsKeyPressed(
        key: i32
    ) -> bool;  def IsKeyPressedRepeat(key: i32) -> bool;  def IsKeyDown(key: i32) -> bool;  def SetTargetFPS(
        fps: i32
    ) -> None;  obj GalleryImage {
        has data: u64,
            width: i32,
            height: i32,
            mipmaps: i32,
            format: i32;
    }  def rlReadScreenPixels(width: i32, height: i32) -> u64;  def ExportImage(
        image: GalleryImage, fileName: str
    ) -> bool;  def MemFree(ptr: u64) -> None;
}

"""The keys the gallery's fields understand, by raylib code."""
glob GALLERY_KEYS: list[tuple[int, str]] = [
    (257, "ENTER"),
    (256, "ESCAPE"),
    (259, "BACKSPACE"),
    (261, "DEL"),
    (263, "LEFTARROW"),
    (262, "RIGHTARROW"),
    (268, "HOME"),
    (269, "END"),
    (258, "TAB"),
    (65, "a"),
    (67, "c"),
    (86, "v"),
    (88, "x")
];

def gallery_script(source: UiSource, text: str) {
    for line in text.split(";") {
        words = line.split();
        if not words {
            continue;
        }
        kind = words[0];
        if kind == "move" {
            source.script(UiStep(kind="move", x=int(words[1]), y=int(words[2])));
        } elif kind == "click" or kind == "rclick" or kind == "double" {
            script_click(
                source, int(words[1]), int(words[2]), 1 if kind == "rclick" else 0, kind == "double"
            );
        } elif kind == "drag" {
            script_drag(source, int(words[1]), int(words[2]), int(words[3]), int(words[4]));
        } elif kind == "wheel" {
            source.script(UiStep(kind="wheel", amount=float(words[1])));
        } elif kind == "key" {
            source.script(UiStep(kind="key", words=words[1]));
        } elif kind == "type" {
            source.script(UiStep(kind="type", words=" ".join(words[1:])));
        } elif kind == "idle" {
            for _ in range(int(words[1])) {
                source.script(UiStep(kind="idle"));
            }
        }
    }
}

def gallery_shot(path: str) {
    width = GetRenderWidth();
    height = GetRenderHeight();
    pixels = rlReadScreenPixels(width, height);
    if pixels != u64(0) {
        ExportImage(
            GalleryImage(data=pixels, width=width, height=height, mipmaps=i32(1), format=i32(7)), path
        );
        MemFree(pixels);
    }
}

with entry {
    SetConfigFlags(u32(4 | 8192));
    InitWindow(i32(1100), i32(680), "QuakePassion interface gallery");
    SetTargetFPS(i32(60));
    canvas = ScreenCanvas();
    canvas.open(os.getenv("QP_UI_FONT", ""));
    stage = Stage(canvas=canvas);

    top = Box();
    bar = MenuBar(
        titles=["File", "Edit", "View", "Help"],
        menus=[
            [
                MenuItem(text="New scene", command="new", keys="Ctrl+N"),
                MenuItem(text="Open...", command="open", keys="Ctrl+O"),
                MenuItem(text="Save", command="save", keys="Ctrl+S"),
                MenuItem(rule=True),
                MenuItem(text="Quit", command="quit")
            ],
            [
                MenuItem(text="Undo", command="undo", keys="Ctrl+Z"),
                MenuItem(text="Redo", command="redo", keys="Ctrl+Y", enabled=False),
                MenuItem(rule=True),
                MenuItem(text="Snap to grid", command="snap", ticked=True)
            ],
            [MenuItem(text="Wireframe", command="wire"), MenuItem(text="Textured", command="tex", ticked=True)],
            [MenuItem(text="About", command="about")]
        ]
    );
    top.adopt(bar);
    tools = Box(across=True, pad=4, gap=4, fill="panel");
    top.adopt(tools);
    tools.adopt(PushButton(text="Play", glyph="play", command="play", bold=True, hint="Run the level"));
    tools.adopt(PushButton(text="Pause", glyph="pause", command="pause", hint="Pause the simulation"));
    tools.adopt(PushButton(text="Stop", glyph="stop", command="stop", enabled=False, hint="Back to editing"));
    tools.adopt(PushButton(glyph="step", command="step", hint="Advance one tick"));
    tools.adopt(Spacer(size=12));
    tools.adopt(Check(text="Snap", command="snap", on_now=True, hint="Snap moves to the grid"));
    tools.adopt(Spacer(grow=1));
    tools.adopt(Label(text="e1m1  |  Quake", tone="dim"));

    body = Box(across=True, grow=1);
    top.adopt(body);
    left = Box(size=260, fill="panel");
    body.adopt(left);
    left.adopt(Header(text="Scene"));
    search_row = Box(pad=4);
    left.adopt(search_row);
    search = TextField(ghost="Filter entities", command="filter", live=True, hint="Type to filter the list");
    search_row.adopt(search);
    tree = TreeView(pick="select", toggle="fold", open_command="focus", grow=1, hint="Click to select, double click to look");
    left.adopt(tree);
    classes = ["worldspawn", "func_door", "func_button", "light", "monster_army", "monster_dog", "item_health", "trigger_multiple"];
    rows: list[TreeRow] = [];
    for (i, name) in enumerate(classes) {
        rows.append(TreeRow(key="g" + str(i), text=name, branch=True, opened=i < 3, note=str(3 + i)));
        if i < 3 {
            for j in range(3 + i) {
                rows.append(
                    TreeRow(
                        key=str(i * 10 + j),
                        text=name + " " + str(j),
                        depth=1,
                        picked=i == 1 and j == 1,
                        tone="text" if j != 2 else "dim",
                        note="#" + str(i * 10 + j)
                    )
                );
            }
        }
    }
    for i in range(60) {
        rows.append(TreeRow(key="x" + str(i), text="light " + str(i), depth=1, note="#" + str(100 + i)));
    }
    tree.rows = rows;
    body.adopt(Splitter(target=left, low=160, high=500));

    middle = Tabs(titles=["Viewport", "Notes"], grow=1);
    body.adopt(middle);
    view = ViewArea(hint="The scene shows here");
    middle.adopt(view);
    notes = Box(pad=12, gap=8, fill="window");
    middle.adopt(notes);
    notes.adopt(Label(text="A second page, shown when its tab is clicked."));

    right = Box(size=300, fill="panel");
    body.adopt(Splitter(target=right, after=True, low=200, high=520));
    body.adopt(right);
    right.adopt(Header(text="Inspector"));
    scroller = Scroll(grow=1);
    right.adopt(scroller);
    form = Box(pad=6, gap=4);
    scroller.adopt(form);
    pairs = [
        ("classname", "func_door"),
        ("targetname", "t3"),
        ("angle", "90"),
        ("speed", "100"),
        ("wait", "-1"),
        ("sounds", "2"),
        ("lip", "8"),
        ("dmg", "2"),
        ("health", "0"),
        ("message", "This door opens elsewhere and has a long message"),
        ("spawnflags", "0"),
        ("model", "*12"),
        ("target", ""),
        ("killtarget", ""),
        ("team", ""),
        ("origin", "480 -352 88"),
        ("_color", "1 0.8 0.6"),
        ("light", "300"),
        ("style", "0"),
        ("delay", "0")
    ];
    for (key, value) in pairs {
        row = Box(across=True, gap=4);
        form.adopt(row);
        row.adopt(Label(text=key, tone="dim", size=96));
        row.adopt(TextField(value=value, command="set " + key, grow=1, hint="Enter commits, Escape cancels"));
    }
    actions = Box(across=True, gap=4);
    form.adopt(actions);
    actions.adopt(PushButton(text="Duplicate", command="duplicate", grow=1));
    actions.adopt(PushButton(text="Delete", command="delete", grow=1));

    status = Box(across=True, pad=4, gap=12, fill="header");
    top.adopt(status);
    hint = Label(text="", tone="dim", grow=1);
    status.adopt(hint);
    last = Label(text="", tone="accent", size=320, align=1);
    status.adopt(last);
    stage.open(top);

    source = UiSource();
    script = os.getenv("QP_UI_SCRIPT", "");
    shot = os.getenv("QP_UI_SHOT", "");
    if script {
        gallery_script(source, script);
    }
    settle = 3;
    while not WindowShouldClose() {
        keys: list[str] = [];
        for (code, name) in GALLERY_KEYS {
            if IsKeyPressed(i32(code)) or IsKeyPressedRepeat(i32(code)) {
                keys.append(name);
            }
        }
        typed = "";
        while True {
            code = int(GetCharPressed());
            if code <= 0 {
                break;
            }
            typed += chr(code);
        }
        ctrl = IsKeyDown(i32(341)) or IsKeyDown(i32(343)) or IsKeyDown(i32(345)) or IsKeyDown(i32(347));
        shift = IsKeyDown(i32(340)) or IsKeyDown(i32(344));
        frame = source.read(float(GetFrameTime()), keys, typed, shift, ctrl, False);
        stage.frame(frame, int(GetScreenWidth()), int(GetScreenHeight()), float(GetFrameTime()));
        bar.track(stage);
        tree.track(stage);
        for command in stage.take_commands() {
            last.text = "command: " + command;
            print(command);
            if command == "quit" {
                settle = -1;
            }
        }
        hint.text = stage.hint();
        BeginDrawing();
        ClearBackground(Color(r=u8(21), g=u8(20), b=u8(18), a=u8(255)));
        stage.paint();
        EndDrawing();
        if settle < 0 {
            break;
        }
        if script and source.pending() == 0 {
            settle -= 1;
            if settle == 0 {
                if shot {
                    gallery_shot(shot);
                }
                break;
            }
        }
    }
    canvas.close();
    CloseWindow();
}
