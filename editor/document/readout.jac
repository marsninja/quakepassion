"""The developer's readout: what the figures the system gives are, in the
words the status bar shows."""

"""The megabytes `ps -o rss=` says a program holds in memory: it answers in
kilobytes, with spaces about the figure (0.0 when it said nothing that is a
number)."""
def resident_megabytes(said: str) -> float {
    word = said.strip().split("\n")[0].strip() if said.strip() else "";
    if not word.isdigit() {
        return 0.0;
    }
    return float(int(word)) / 1024.0;
}

"""A count of megabytes as the readout shows it: whole megabytes, and from
a thousand of them gigabytes to one place. Nothing when it is not known."""
def memory_words(megabytes: float) -> str {
    if megabytes <= 0.0 {
        return "";
    }
    if megabytes >= 1000.0 {
        return str(round(megabytes / 1024.0, 1)) + " GB";
    }
    return str(int(round(megabytes))) + " MB";
}

"""How brightly something that fired is shown: 1 as it fires, falling to
nothing over `span` seconds; 0 for what has not fired (`last` below zero)."""
def flash_level(now: float, last: float, span: float = 1.0) -> float {
    if last < 0.0 or now < last {
        return 0.0;
    }
    return max(0.0, 1.0 - (now - last) / max(0.001, span));
}

"""Where the boxes of a graph laid out in columns go in a panel: [x, y] of
each box from the panel's corner, `wide` and `tall` a box with `gap`
between, and the panel's own [width, height] last."""
def graph_places(places: list[list[int]], wide: int, tall: int, gap: int) -> list[list[int]] {
    found: list[list[int]] = [];
    most_x = 0;
    most_y = 0;
    for place in places {
        x = gap + place[0] * (wide + gap);
        y = gap + place[1] * (tall + gap);
        found.append([x, y]);
        most_x = max(most_x, x + wide + gap);
        most_y = max(most_y, y + tall + gap);
    }
    found.append([most_x, most_y]);
    return found;
}
