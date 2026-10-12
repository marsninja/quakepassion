"""Working text out for the toolkit, with nothing drawn: where a passage of
several lines breaks to fit a width, which row a place in it falls on, how
a passage is written as the one line a map's field holds, and which of a
list of choices what was typed asks for."""

"""Where each row of a passage begins. A new row follows every line break,
and wherever the words would run past `room`: after the last space that
fits, or inside a word that is too long by itself. `widths` says how wide
each character draws."""
def row_starts(text: str, widths: list[int], room: int) -> list[int] {
    starts: list[int] = [0];
    used = 0;
    # The place after the last space of the row being filled.
    gap = -1;
    for i in range(len(text)) {
        if text[i] == "\n" {
            starts.append(i + 1);
            used = 0;
            gap = -1;
            continue;
        }
        wide = widths[i] if i < len(widths) else 0;
        if used + wide > room and i > starts[-1] {
            begin = gap if gap > starts[-1] else i;
            starts.append(begin);
            used = 0;
            for j in range(begin, i) {
                used += widths[j] if j < len(widths) else 0;
            }
            gap = -1;
        }
        used += wide;
        if text[i] == " " {
            gap = i + 1;
        }
    }
    return starts;
}

"""The row a place in the passage is on."""
def row_of(starts: list[int], place: int) -> int {
    found = 0;
    for (row, begin) in enumerate(starts) {
        if begin <= place {
            found = row;
        }
    }
    return found;
}

"""Where a row begins and where its words end: before its line break, when
it ends in one."""
def row_span(text: str, starts: list[int], row: int) -> tuple[int, int] {
    if row < 0 or row >= len(starts) {
        return (len(text), len(text));
    }
    begin = starts[row];
    end = starts[row + 1] if row + 1 < len(starts) else len(text);
    if end > begin and text[end - 1] == "\n" {
        end -= 1;
    }
    return (begin, end);
}

"""The number of the line a row begins, counting from one, or 0 for a row
that goes on with the line the row above it began."""
def row_line(text: str, starts: list[int], row: int) -> int {
    if row < 0 or row >= len(starts) {
        return 0;
    }
    begin = starts[row];
    if begin > 0 and text[begin - 1] != "\n" {
        return 0;
    }
    return text[:begin].count("\n") + 1;
}

"""A passage as the one line a map's field holds: its line breaks written
as a backslash and an n, the way the games read them."""
def passage_line(text: str) -> str {
    return text.replace("\r", "").replace("\n", "\\n");
}

"""The passage such a line holds."""
def passage_of(line: str) -> str {
    return line.replace("\\n", "\n");
}

"""The choices what was typed asks for: those that begin with it first, then
those that hold it elsewhere, each in the order given and capitals ignored.
Nothing typed asks for them all."""
def combo_matches(typed: str, choices: list[str]) -> list[str] {
    wanted = typed.strip().lower();
    if not wanted {
        return list(choices);
    }
    leading: list[str] = [];
    holding: list[str] = [];
    for choice in choices {
        lowered = choice.lower();
        if lowered.startswith(wanted) {
            leading.append(choice);
        } elif wanted in lowered {
            holding.append(choice);
        }
    }
    return leading + holding;
}

"""Which row of a list should be shown first so that row `lit` is among the
`most` rows on show, moving as little as it can from `first`."""
def list_first(first: int, lit: int, most: int, count: int) -> int {
    begin = first;
    if lit >= 0 and lit < begin {
        begin = lit;
    }
    if lit >= begin + most {
        begin = lit - most + 1;
    }
    return max(0, min(begin, max(0, count - most)));
}
