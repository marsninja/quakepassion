import from editor.ui.logview { log_reach, log_window, log_fitted }

test "a log panel shows the newest lines, and older ones when scrolled back" {
    said = ["line " + str(number) for number in range(1, 11)];
    assert log_window(said, 4) == ["line 7", "line 8", "line 9", "line 10"];
    assert log_window(said, 4, 3) == ["line 4", "line 5", "line 6", "line 7"];
    # No further back than the oldest line at the top.
    assert log_reach(10, 4) == 6 and log_window(said, 4, 6) == said[:4] and log_window(said, 4, 99) == said[:4];
    assert log_window(said, 4, -5) == said[6:];
    # Fewer lines than rows: all of them, and nowhere to scroll.
    assert log_window(said[:2], 4) == ["line 1", "line 2"] and log_reach(2, 4) == 0 and log_window(said[:2], 4, 3) == said[:2];
    assert log_window([], 4) == [] and log_window(said, 0) == ["line 10"];
}

test "a long line is cut to fit, and says so" {
    assert log_fitted("short", 20) == "short";
    assert log_fitted("a line too long to fit", 10) == "a line ...";
    assert log_fitted("exactly10!", 10) == "exactly10!";
    assert log_fitted("anything", 2) == "an" and log_fitted("anything", 0) == "";
}
