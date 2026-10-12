import from editor.ui.canvas { TraceCanvas }
import from editor.ui.input { UiSource, UiStep, script_click }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets { Box, PushButton, TextField, ViewArea, TreeView, TreeRow }

"""Run frames until the scripted steps are played, and so many more."""
def play(stage: Stage, source: UiSource, more: int = 1) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
    }
    for extra in range(more) {
        stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
    }
}

def flown(stage: Stage, canvas: TraceCanvas, words: str) -> int {
    canvas.strokes = [];
    stage.paint();
    return len([stroke for stroke in canvas.strokes if stroke.kind == "text" and stroke.words == words]);
}

test "a hint is shown beside the pointer once it has rested on a control a while" {
    top = Box();
    row = Box(across=True);
    top.adopt(row);
    row.adopt(PushButton(text="Carve", command="ed_carve", hint="Cut the selection out of what it overlaps"));
    row.adopt(PushButton(text="Plain", command="ed_plain"));
    view = ViewArea(grow=1, hint="Drag to look about");
    top.adopt(view);
    canvas = TraceCanvas();
    stage = Stage(canvas=canvas);
    stage.open(top);
    source = UiSource();
    source.script(UiStep(kind="move", x=20, y=10));
    play(stage, source);
    said = "Cut the selection out of what it overlaps";
    # Not at once; after most of a second it is there; and it goes when the pointer moves.
    assert stage.hint() == said and flown(stage, canvas, said) == 0;
    play(stage, source, 60);
    assert stage.flyover() == said and flown(stage, canvas, said) == 1;
    source.script(UiStep(kind="move", x=22, y=11));
    play(stage, source);
    assert flown(stage, canvas, said) == 0;
    # A control with no hint has none to show; a surface that is worked on keeps its for the hint bar.
    source.script(UiStep(kind="move", x=100, y=10));
    play(stage, source, 60);
    assert stage.flyover() == "";
    source.script(UiStep(kind="move", x=400, y=300));
    play(stage, source, 60);
    assert stage.hint() == "Drag to look about" and stage.flyover() == "" and flown(stage, canvas, "Drag to look about") == 0;
    # Turned off, nothing flies.
    source.script(UiStep(kind="move", x=20, y=10));
    play(stage, source, 60);
    assert stage.flyover() == said;
    stage.flyovers = False;
    assert stage.flyover() == "" and flown(stage, canvas, said) == 0;
}

test "Tab goes from one field to the next, and round; Shift goes back" {
    top = Box();
    first = TextField(command="one");
    second = TextField(command="two");
    third = TextField(command="three");
    top.adopt(first);
    top.adopt(PushButton(text="Between"));
    top.adopt(second);
    hidden = Box();
    hidden.shown = False;
    hidden.adopt(TextField(command="unseen"));
    top.adopt(hidden);
    top.adopt(ViewArea(size=100));
    top.adopt(third);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    source = UiSource();
    play(stage, source);
    # Nothing has the keyboard: Tab is nobody's, and is left for the owner.
    assert not stage.next_focus();
    stage.focus_on(first);
    assert stage.next_focus() and stage.focus is second;
    # Past the view and what is not shown, to the third; and round to the first.
    assert stage.next_focus() and stage.focus is third;
    assert stage.next_focus() and stage.focus is first and first.focused and not third.focused;
    assert stage.next_focus(True) and stage.focus is third;
    assert stage.next_focus(True) and stage.focus is second;
    # The key itself: taken by the stage, and not left loose.
    stage.frame(source.read(0.016, ["TAB"], "", False, False, False), 800, 600, 0.016);
    assert stage.focus is third and stage.loose_keys == [];
    # One field alone has nowhere to go.
    lone = Box();
    only = TextField(command="only");
    lone.adopt(only);
    alone = Stage(canvas=TraceCanvas());
    alone.open(lone);
    alone.focus_on(only);
    assert not alone.next_focus() and alone.focus is only;
}

test "a control says the command it asks for" {
    assert PushButton(text="Carve", command="ed_carve").asks() == "ed_carve";
    assert TextField(command="ed_filter").asks() == "ed_filter" and TreeView(pick="ed_select").asks() == "ed_select";
    assert Box().asks() == "" and ViewArea().asks() == "";
}
