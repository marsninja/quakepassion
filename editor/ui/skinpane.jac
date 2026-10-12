"""A kept picture that takes the pointer: what is pressed, dragged and
clicked over it is kept for the one who shows it to take, as a view of
the level keeps its own."""

import from .canvas { Canvas }
import from .widget { Widget, Stage, UiEvent }
import from .widgets { Picture }

node SkinPane(Picture) {
    has events: list[UiEvent] = [];

    def on(event: UiEvent, stage: Stage) -> bool {
        if event.kind == "key" or event.kind == "text" {
            return False;
        }
        self.events.append(event);
        return True;
    }

    def take -> list[UiEvent] {
        taken = self.events;
        self.events = [];
        return taken;
    }

    def solid -> bool {
        return True;
    }
}
