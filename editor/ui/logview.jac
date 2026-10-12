"""What a log panel shows of the console's lines: so many rows, ending so
far back from the newest."""

"""How far back a panel of `rows` rows can be scrolled over `count` lines:
until its first row is the oldest line."""
def log_reach(count: int, rows: int) -> int {
    return max(0, count - max(1, rows));
}

"""The lines a panel of `rows` rows shows, oldest first, when it is scrolled
`back` lines from the newest (as far as there are lines to go back to)."""
def log_window(lines: list[str], rows: int, back: int = 0) -> list[str] {
    tall = max(1, rows);
    gone = max(0, min(back, log_reach(len(lines), tall)));
    last = len(lines) - gone;
    return lines[max(0, last - tall):last];
}

"""A line cut to fit so many letters, with a mark that there was more."""
def log_fitted(line: str, letters: int) -> str {
    if letters < 4 or len(line) <= letters {
        return line[:max(0, letters)];
    }
    return line[:letters - 3] + "...";
}
