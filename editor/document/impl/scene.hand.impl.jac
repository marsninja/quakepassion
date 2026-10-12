"""Brushes handed from one entity to another that is already in the
document. Declarations live in scene.jac."""

impl Scene.hand_selection(taker: Item) -> int {
    step = Step(label="Hand to " + taker.title());
    for solid in self.selected_solids() {
        giver = self.owner_of(solid);
        if giver is None or giver is taker {
            continue;
        }
        change = OwnChange(solid=solid, before=giver, after=taker);
        change.redo();
        step.changes.append(change);
    }
    handed = len(step.changes);
    return handed if self.commit(step) else 0;
}
