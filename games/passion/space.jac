"""A space: one room or passage of a Passion level, as the sculptor found it
(`sculpt.jac`) and the dressing and brushwork read it.

Its box (`x`, `y`, `z` low corner in cells, `w` by `d` cells across and `h`
lifts high) bounds the massing cells that are its air; its role says
whether it is a room or a passage, its district and variant whose
materials it takes."""

"""A space."""
node Space {
    has id: int,
        role: str = "room",
        kind: str = "traced",
        district: int = 0,
        x: int = 0,
        y: int = 0,
        z: int = 0,
        w: int = 8,
        d: int = 8,
        h: int = 10,
        tension: float = 0.0,
        sky: bool = False,
        # Which of its district's looks it takes (0 the district's own).
        variant: int = 0,
        # How many lifts of liquid stand in its lowest floor across its box,
        # and whether that liquid kills.
        flood: int = 0,
        deadly: bool = False,
        # The floor levels that matter (lamps hang over them), a cell to
        # stand on ([x, y, z]), and cells kept clear of railings and props.
        levels: list[int] = [],
        stage: list[int] = [],
        kept: list[list[int]] = [];

    def middle_x -> float {
        return float(self.x) + float(self.w) * 0.5;
    }

    def middle_y -> float {
        return float(self.y) + float(self.d) * 0.5;
    }
}
