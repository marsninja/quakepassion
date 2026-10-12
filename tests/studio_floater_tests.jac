import from editor.ui.canvas { TraceCanvas, Rect, rects_outside, Theme, light_theme }
import from editor.ui.input { UiSource, script_click, script_drag }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets { Box, PushButton, ViewArea, Floater }

"""Run frames until the scripted steps are played, plus one to settle."""
def play(stage: Stage, source: UiSource, width: int = 800, height: int = 600) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
    }
    stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
}

"""A stage with a button filling it, and a window floating over part of it."""
def floated -> tuple[Stage, Floater, ViewArea, PushButton] {
    under = PushButton(text="Under", command="under", grow=1);
    top = Box();
    top.adopt(under);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    view = ViewArea();
    window = Floater(title="3D 2", command="close 2", note="its own camera");
    window.adopt(view);
    window.area = Rect(x=100, y=100, w=300, h=200);
    stage.open(window);
    return (stage, window, view, under);
}

test "a floating window lays its one widget under its bar and over its foot" {
    made = floated();
    stage = made[0];
    window = made[1];
    view = made[2];
    source = UiSource();
    play(stage, source);
    assert view.area.same(Rect(x=101, y=120, w=298, h=166)) and window.inside().same(view.area);
    assert window.cross().same(Rect(x=380, y=100, w=20, h=20)) and window.corner().same(Rect(x=386, y=286, w=14, h=14));
    # What is inside takes the pointer there; outside the window, what lies under it does.
    script_click(source, 200, 200);
    play(stage, source);
    assert len([event for event in view.take() if event.kind == "click"]) == 1 and stage.take_commands() == [];
    script_click(source, 600, 400);
    play(stage, source);
    # (The view, which had the keyboard, is told it has lost it, and nothing else.)
    assert stage.take_commands() == ["under"] and [event.kind for event in view.take()] == ["blur"];
    # A click on its bar is its own: nothing under it hears of it.
    script_click(source, 200, 108);
    play(stage, source);
    assert stage.take_commands() == [] and len(view.take()) == 0;
}

test "it is moved by its bar, sized by its corner, kept on the stage, and closed by its cross" {
    made = floated();
    stage = made[0];
    window = made[1];
    view = made[2];
    source = UiSource();
    play(stage, source);
    script_drag(source, 200, 108, 260, 148);
    play(stage, source);
    assert window.area.same(Rect(x=160, y=140, w=300, h=200)) and window.taken == "";
    assert view.area.same(Rect(x=161, y=160, w=298, h=166));
    # The corner pulled out; pulled in past what it may be, it stops there.
    script_drag(source, 455, 335, 505, 395);
    play(stage, source);
    assert window.area.same(Rect(x=160, y=140, w=350, h=260));
    script_drag(source, 505, 395, 205, 150);
    play(stage, source);
    assert window.area.w == window.least_wide and window.area.h == window.least_tall and window.area.x == 160;
    # Dragged off the stage it stops at the edge.
    script_drag(source, 200, 148, 2, 2);
    play(stage, source);
    assert window.area.x == 0 and window.area.y == 0;
    script_drag(source, 40, 8, 799, 599);
    play(stage, source);
    assert window.area.right() == 800 and window.area.bottom() == 600;
    # Its cross asks for its command; a drag that begins on the cross moves nothing.
    at = window.cross();
    before = window.area;
    script_drag(source, at.x + 10, at.y + 10, at.x - 80, at.y - 80);
    play(stage, source);
    assert window.area.same(before) and stage.take_commands() == [];
    script_click(source, at.x + 10, at.y + 10);
    play(stage, source);
    assert stage.take_commands() == ["close 2"];
    # Closed, the stage has one layer and what was under it takes the pointer again.
    stage.close(window);
    script_click(source, at.x - 100, at.y + 60);
    play(stage, source);
    assert len(stage.layers()) == 1 and stage.take_commands() == ["under"];
}

test "it paints its bar and its foot, and leaves what is inside unpainted" {
    made = floated();
    stage = made[0];
    window = made[1];
    canvas = TraceCanvas();
    stage.canvas = canvas;
    source = UiSource();
    play(stage, source);
    stage.paint();
    said = canvas.words();
    assert "3D 2" in said and "its own camera" in said;
    inside = window.inside();
    fills = [
        stroke.area for stroke in canvas.strokes
        if stroke.kind == "fill" and stroke.area.within(inside).same(inside)
    ];
    # Only the button beneath fills what is inside the window: the window itself does not.
    assert len(fills) == 1;
}

test "a floating window with bounds stays within them" {
    made = floated();
    stage = made[0];
    window = made[1];
    source = UiSource();
    play(stage, source);
    window.bounds = Rect(x=50, y=40, w=500, h=400);
    script_drag(source, 200, 108, 790, 590);
    play(stage, source);
    assert window.area.right() == 550 and window.area.bottom() == 440;
    script_drag(source, window.area.x + 30, window.area.y + 8, 2, 2);
    play(stage, source);
    assert window.area.x == 50 and window.area.y == 40;
    # Sized past its bounds, it is as large as they are and no larger.
    grip = window.corner();
    script_drag(source, grip.x + 6, grip.y + 6, 795, 595);
    play(stage, source);
    assert window.area.same(Rect(x=50, y=40, w=500, h=400));
}

test "what is left of a rectangle with others cut out of it" {
    area = Rect(x=0, y=0, w=100, h=100);
    assert len(rects_outside(area, [])) == 1 and rects_outside(area, [])[0].same(area);
    # A hole in the middle leaves four pieces that cover all but the hole and do not overlap.
    hole = Rect(x=40, y=30, w=20, h=30);
    pieces = rects_outside(area, [hole]);
    assert len(pieces) == 4;
    total = 0;
    for (index, piece) in enumerate(pieces) {
        total += piece.w * piece.h;
        assert piece.within(hole).w == 0 or piece.within(hole).h == 0;
        for other in pieces[index + 1:] {
            shared = piece.within(other);
            assert shared.w == 0 or shared.h == 0;
        }
    }
    assert total == 100 * 100 - 20 * 30;
    # One that only reaches in at a corner, one outside, and one that covers it all.
    corner = rects_outside(area, [Rect(x=80, y=-10, w=50, h=40)]);
    assert sum([piece.w * piece.h for piece in corner]) == 100 * 100 - 20 * 30 and len(corner) == 2;
    assert len(rects_outside(area, [Rect(x=200, y=200, w=10, h=10)])) == 1;
    assert rects_outside(area, [Rect(x=-5, y=-5, w=200, h=200)]) == [] and rects_outside(Rect(), [hole]) == [];
    # Two holes.
    two = rects_outside(area, [hole, Rect(x=0, y=0, w=10, h=10)]);
    assert sum([piece.w * piece.h for piece in two]) == 100 * 100 - 20 * 30 - 100;
}

test "a floating window is kept within its room, once there is a room" {
    stage = Stage(canvas=TraceCanvas());
    stage.open(Box());
    casing = Floater(title="Shape");
    casing.area = Rect(x=600, y=300, w=300, h=200);
    # Before anything is laid out there is nothing to keep it within: it stays as it was put.
    casing.settle(stage);
    assert casing.area.same(Rect(x=600, y=300, w=300, h=200));
    # In a window too small for where it stands it is brought in whole.
    stage.width = 800;
    stage.height = 400;
    casing.settle(stage);
    assert casing.area.same(Rect(x=500, y=200, w=300, h=200));
    # Within bounds of its own, when it has them; and never smaller than its least.
    casing.bounds = Rect(x=100, y=50, w=250, h=120);
    casing.settle(stage);
    assert casing.area.x == 100 and casing.area.y == 50 and casing.area.w == 250 and casing.area.h == 120;
    casing.area = Rect(x=0, y=0, w=10, h=10);
    casing.settle(stage);
    assert casing.area.w == casing.least_wide and casing.area.h == casing.least_tall;
}

test "the light colours differ from the dark where it matters, and share their metrics" {
    dark = Theme();
    light = light_theme();
    assert light.row == dark.row and light.font == dark.font and light.pad == dark.pad;
    # Words are dark on light panels, and light on dark ones.
    assert light.text.r + light.text.g + light.text.b < light.panel.r + light.panel.g + light.panel.b;
    assert dark.text.r + dark.text.g + dark.text.b > dark.panel.r + dark.panel.g + dark.panel.b;
    assert light.field.r > 200 and dark.field.r < 60;
}
