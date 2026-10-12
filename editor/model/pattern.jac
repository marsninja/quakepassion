"""The patterns a skin is painted in: which texels of the picture a pattern
covers, so that a brush lays its colour on those and leaves the rest."""

"""The patterns there are."""
glob SKIN_PATTERNS: list[str] = ["solid", "checks", "stripes", "bars", "dots"];

"""Whether a pattern covers a texel. `grain` is how many texels wide one of
its squares, stripes or dots is: checks are squares of the colour and of
none by turns, stripes run across and bars run down, and dots are discs,
one to each square of twice the grain. Solid, and any pattern that is not
one of them, covers every texel."""
def pattern_covers(pattern: str, x: int, y: int, grain: int = 4) -> bool {
    size = max(1, grain);
    if pattern == "checks" {
        return (x // size + y // size) % 2 == 0;
    }
    if pattern == "stripes" {
        return (y // size) % 2 == 0;
    }
    if pattern == "bars" {
        return (x // size) % 2 == 0;
    }
    if pattern == "dots" {
        cell = size * 2;
        across = float(x % cell) + 0.5 - float(size);
        down = float(y % cell) + 0.5 - float(size);
        reach = float(size) * 0.5;
        return across * across + down * down <= reach * reach;
    }
    return True;
}
