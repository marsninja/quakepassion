"""Numbers as the games read them from text. A map's entity fields are
strings, and the originals turn them into numbers with C's atof and atoi
(ED_ParseField, G_SpawnFloat): the number the text starts with, and zero
when it starts with none. Mappers leaned on that: shipped maps carry
`"delay" ""`, `"delay" ".1.25"` and `"light" "175\\"`."""

"""atof: the decimal number `text` starts with, after any blanks; 0.0 when it
starts with none."""
def atof(text: str) -> float {
    i = 0;
    while i < len(text) and text[i] in [" ", "\t", "\n", "\r"] {
        i += 1;
    }
    start = i;
    if i < len(text) and text[i] in ["-", "+"] {
        i += 1;
    }
    end = start;
    seen_digit = False;
    seen_point = False;
    while i < len(text) {
        c = text[i];
        if c >= "0" and c <= "9" {
            seen_digit = True;
            end = i + 1;
        } elif c == "." and not seen_point {
            seen_point = True;
            if seen_digit {
                end = i + 1;
            }
        } else {
            break;
        }
        i += 1;
    }
    if not seen_digit {
        return 0.0;
    }
    # An exponent counts only when digits follow it.
    if i < len(text) and text[i] in ["e", "E"] {
        j = i + 1;
        if j < len(text) and text[j] in ["-", "+"] {
            j += 1;
        }
        digits = j;
        while j < len(text) and text[j] >= "0" and text[j] <= "9" {
            j += 1;
        }
        if j > digits {
            end = j;
        }
    }
    return float(text[start:end]);
}

"""atoi: the whole number `text` starts with, after any blanks; 0 when it
starts with none. A fraction is dropped, as atoi stops at the point."""
def atoi(text: str) -> int {
    i = 0;
    while i < len(text) and text[i] in [" ", "\t", "\n", "\r"] {
        i += 1;
    }
    start = i;
    if i < len(text) and text[i] in ["-", "+"] {
        i += 1;
    }
    digits = i;
    while i < len(text) and text[i] >= "0" and text[i] <= "9" {
        i += 1;
    }
    if i == digits {
        return 0;
    }
    return int(text[start:i]);
}
