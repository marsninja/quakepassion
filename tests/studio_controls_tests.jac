import from editor.ui.canvas { TraceCanvas, Rect }
import from editor.ui.input { UiSource, UiStep, script_click }
import from editor.ui.widget { Widget, Stage }
import from editor.ui.widgets { Box }
import from editor.ui.controls { Combo, ComboList, TextArea }
import from editor.ui.passage { row_starts, row_of, row_span, row_line, passage_line, passage_of, combo_matches, list_first }

"""Run frames until the scripted steps are played, plus one to settle."""
def play(stage: Stage, source: UiSource, width: int = 800, height: int = 600) {
    while source.pending() > 0 {
        stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
    }
    stage.frame(source.read(0.016, [], "", False, False, False), width, height, 0.016);
}

def press_key(source: UiSource, name: str, ctrl: bool = False) {
    if ctrl {
        source.script(UiStep(kind="ctrl", button=1));
    }
    source.script(UiStep(kind="key", words=name));
    if ctrl {
        source.script(UiStep(kind="ctrl", button=0));
    }
}

def type_words(source: UiSource, words: str) {
    source.script(UiStep(kind="type", words=words));
}

"""A stage with a combo along its top."""
def combo_stage -> tuple[Stage, Combo] {
    field = Combo(command="set target", choices=["door_a", "door_b", "lift", "trapdoor"], value="lift");
    top = Box();
    top.adopt(field);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    return (stage, field);
}

"""A stage with a box for a passage: along its top, or `wide` across at its left."""
def area_stage(value: str, wide: int = 0) -> tuple[Stage, TextArea] {
    area = TextArea(command="set message", value=value, size=wide);
    top = Box(across=wide > 0);
    top.adopt(area);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    return (stage, area);
}

test "a passage breaks at its line breaks and after the last space that fits" {
    ones = [1 for i in range(13)];
    assert row_starts("one two three", ones, 8) == [0, 8];
    # A word too long for a row is broken where the row ends.
    assert row_starts("one two three", ones, 4) == [0, 4, 8, 12];
    assert row_starts("ab\n\ncd", ones, 8) == [0, 3, 4];
    assert row_starts("", [], 8) == [0];
}

test "a place in a passage is on the last row that begins at or before it" {
    starts = [0, 3, 4];
    assert row_of(starts, 0) == 0 and row_of(starts, 2) == 0 and row_of(starts, 3) == 1 and row_of(starts, 6) == 2;
    assert row_span("ab\n\ncd", starts, 0) == (0, 2);
    assert row_span("ab\n\ncd", starts, 1) == (3, 3);
    assert row_span("ab\n\ncd", starts, 2) == (4, 6);
    # A row the words ran over the end of keeps all of them.
    assert row_span("one two three", [0, 8], 0) == (0, 8);
}

test "a passage is written as one line with its breaks as backslash n" {
    assert passage_line("one\ntwo") == "one\\ntwo";
    assert passage_of("one\\ntwo") == "one\ntwo";
    assert passage_of(passage_line("a\n\nb")) == "a\n\nb";
    assert passage_line("plain") == "plain";
}

test "what is typed asks for the choices that begin with it, then those that hold it" {
    names = ["door_a", "trapdoor", "Door_b", "lift"];
    assert combo_matches("door", names) == ["door_a", "Door_b", "trapdoor"];
    assert combo_matches("", names) == names and combo_matches("  ", names) == names;
    assert combo_matches("zz", names) == [];
}

test "a list keeps its lit row among the rows on show" {
    assert list_first(0, 3, 8, 20) == 0;
    assert list_first(0, 9, 8, 20) == 2;
    assert list_first(5, 2, 8, 20) == 2;
    assert list_first(15, -1, 8, 20) == 12;
    assert list_first(0, 2, 8, 3) == 0;
}

test "a combo lists its choices, narrows them to what is typed, and Enter takes the lit one" {
    made = combo_stage();
    stage = made[0];
    field = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    play(stage, source);
    lister = field.listed(stage);
    assert lister is not None and lister.rows == ["door_a", "door_b", "lift", "trapdoor"];
    assert lister.area.same(Rect(x=0, y=22, w=800, h=92));
    press_key(source, "a", True);
    type_words(source, "door");
    play(stage, source);
    lister = field.listed(stage);
    assert lister is not None and lister.rows == ["door_a", "door_b", "trapdoor"] and lister.lit == -1;
    press_key(source, "DOWNARROW");
    press_key(source, "DOWNARROW");
    play(stage, source);
    assert lister.lit == 1;
    press_key(source, "ENTER");
    play(stage, source);
    assert stage.take_commands() == ["set target \"door_b\""];
    assert field.listed(stage) is None and field.value == "door_b" and not field.focused;
}

test "a combo takes what is typed when no row is lit" {
    made = combo_stage();
    stage = made[0];
    field = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    press_key(source, "a", True);
    type_words(source, "gate");
    play(stage, source);
    # Nothing matches, so no list is held open.
    assert field.listed(stage) is None;
    press_key(source, "ENTER");
    play(stage, source);
    assert stage.take_commands() == ["set target \"gate\""];
}

test "clicking a row of a combo's list asks for that row, not for what was typed" {
    made = combo_stage();
    stage = made[0];
    field = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    press_key(source, "a", True);
    type_words(source, "tr");
    play(stage, source);
    lister = field.listed(stage);
    assert lister is not None and lister.rows == ["trapdoor"];
    script_click(source, 50, 30);
    play(stage, source);
    assert stage.take_commands() == ["set target \"trapdoor\""];
    assert field.listed(stage) is None and not field.focused and field.value == "lift";
}

test "Escape puts a combo's list away, and again leaves the field as it was" {
    made = combo_stage();
    stage = made[0];
    field = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    press_key(source, "a", True);
    type_words(source, "do");
    press_key(source, "ESCAPE");
    play(stage, source);
    assert field.listed(stage) is None and field.focused and field.draft == "do";
    press_key(source, "ESCAPE");
    play(stage, source);
    assert not field.focused and field.value == "lift" and stage.take_commands() == [];
}

test "a box for a passage begins a line on Enter and asks for it all on Ctrl+Enter" {
    made = area_stage("hi\\nthere");
    stage = made[0];
    area = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    play(stage, source);
    assert area.editing and area.draft == "hi\nthere" and area.area.same(Rect(x=0, y=0, w=800, h=57));
    press_key(source, "a", True);
    type_words(source, "one");
    press_key(source, "ENTER");
    type_words(source, "two");
    play(stage, source);
    assert area.draft == "one\ntwo" and area.starts == [0, 4] and area.cursor == 7;
    press_key(source, "ENTER", True);
    play(stage, source);
    assert stage.take_commands() == ["set message \"one\\ntwo\""];
    assert area.value == "one\\ntwo" and not area.focused;
}

test "the cursor of a passage goes up and down keeping how far across it was" {
    made = area_stage("");
    stage = made[0];
    area = made[1];
    source = UiSource();
    script_click(source, 50, 10);
    type_words(source, "abcd");
    press_key(source, "ENTER");
    type_words(source, "xy");
    press_key(source, "ENTER");
    type_words(source, "mnopq");
    play(stage, source);
    assert area.cursor == 13;
    press_key(source, "UPARROW");
    play(stage, source);
    assert area.cursor == 7;
    press_key(source, "UPARROW");
    play(stage, source);
    assert area.cursor == 4;
    press_key(source, "DOWNARROW");
    press_key(source, "DOWNARROW");
    play(stage, source);
    assert area.cursor == 13;
    press_key(source, "HOME");
    play(stage, source);
    assert area.cursor == 8;
    # Escape gives the change up.
    press_key(source, "ESCAPE");
    play(stage, source);
    assert not area.focused and area.value == "" and stage.take_commands() == [];
}

test "a passage wraps to the width of its box, and a press elsewhere asks for it" {
    made = area_stage("", 86);
    stage = made[0];
    area = made[1];
    source = UiSource();
    script_click(source, 40, 10);
    type_words(source, "one two three four");
    play(stage, source);
    assert area.starts == [0, 8];
    # The second row is under the first: a press there puts the cursor in it.
    script_click(source, 6, 25);
    play(stage, source);
    assert area.cursor == 8;
    script_click(source, 400, 300);
    play(stage, source);
    assert stage.take_commands() == ["set message \"one two three four\""];
}

test "a row that begins a line has the line's number, and one that goes on with it has none" {
    # "ab cd" over two rows, then a line of its own.
    text = "ab cd\nef";
    starts = [0, 3, 6];
    assert row_line(text, starts, 0) == 1 and row_line(text, starts, 1) == 0 and row_line(text, starts, 2) == 2;
    assert row_line("", [0], 0) == 1 and row_line(text, starts, 5) == 0;
}

test "a numbered box keeps its numbers to the left of where a press lands" {
    area = TextArea(command="set words", value="abcd\\nxy", numbered=True);
    top = Box();
    top.adopt(area);
    stage = Stage(canvas=TraceCanvas());
    stage.open(top);
    source = UiSource();
    # The numbers take four small characters and a gap: the words begin after them.
    script_click(source, 5 + area.gutter(stage.canvas) + 15, 25);
    play(stage, source);
    assert area.gutter(stage.canvas) > 20 and area.cursor == 7;
    press_key(source, "UPARROW");
    play(stage, source);
    assert area.cursor == 2;
    # A page up from the first rows ends at the passage's beginning.
    press_key(source, "PGDN");
    press_key(source, "PGUP");
    play(stage, source);
    assert area.cursor == 0;
}
