import from editor.ui.canvas { TraceCanvas }
import from editor.ui.input { UiSource, script_click, script_drag }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets { Box, ViewArea, Sash }

"""Run frames until the scripted steps are played, plus one to settle."""
def play(stage: Stage, source: UiSource) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
    }
    stage.frame(source.read(0.016, [], "", False, False, False), 800, 600, 0.016);
}

test "a bar between two views asks for the share the pointer is dragged to" {
    top = Box(across=True);
    first = ViewArea(grow=1);
    second = ViewArea(grow=1);
    top.adopt(first);
    top.adopt(Sash(command="split x"));
    top.adopt(second);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    source = UiSource();
    play(stage, source);
    # Three wide between two halves of what is left.
    assert first.area.w == 398 and second.area.x == 401 and second.area.w == 399 , str(first.area.w) + " " + str(second.area.x);
    script_drag(source, 399, 300, 600, 300);
    play(stage, source);
    asked = stage.take_commands();
    assert len(asked) > 1 and asked[-1] == "split x 75" and asked[0].startswith("split x 5") , str(asked);
    # The owner shares the room out by weight: the views follow.
    first.grow = 75;
    second.grow = 25;
    play(stage, source);
    assert first.area.w == 597 and second.area.x == 600 and second.area.w == 200 , str(first.area.w);
    # Dragged past either end it asks for no more than all or nothing; a click asks for nothing.
    script_drag(source, 598, 300, 900, 300);
    play(stage, source);
    assert stage.take_commands()[-1] == "split x 100";
    script_click(source, 598, 300);
    play(stage, source);
    assert stage.take_commands() == [];
}

test "a bar between rows asks by the pointer's height" {
    top = Box();
    upper = ViewArea(grow=1);
    lower = ViewArea(grow=1);
    top.adopt(upper);
    top.adopt(Sash(command="split y"));
    top.adopt(lower);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    source = UiSource();
    play(stage, source);
    assert upper.area.h == 298 and lower.area.y == 301;
    script_drag(source, 400, 299, 400, 150);
    play(stage, source);
    assert stage.take_commands()[-1] == "split y 25";
}
