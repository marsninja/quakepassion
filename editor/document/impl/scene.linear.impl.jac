"""The scene's selection carried through a linear change. Declarations live
in scene.jac."""

impl Scene.remap_selection(
    change: Linear, about: Vec3 | None = None, label: str = "Shear", grid: float = 8.0, locked: bool = True
) -> bool {
    if change.idle() or change.slopes() is None {
        return False;
    }
    middle = about if about is not None else self.selection_hub(grid);
    if middle is None {
        return False;
    }
    step = Step(label=label);
    self spawn Remap(pivot=middle, change=change, step=step, locked=locked);
    return self.commit(step);
}
