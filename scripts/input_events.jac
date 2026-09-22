"""Shared raylib input injection for native desktop acceptance harnesses."""
import from engine.core.app { App }
import from vendor.raylib {
    # AutomationEvent has frame, type, and four contiguous int parameters.
    obj AutomationEvent {
        has frame: u32,
            kind: u32,
            p0: i32,
            p1: i32,
            p2: i32,
            p3: i32;
    }  def PlayAutomationEvent(event: AutomationEvent) -> None;
}

def event(kind: int, a: int, b: int = 0) {
    PlayAutomationEvent(
        AutomationEvent(
            frame=u32(0), kind=u32(kind), p0=i32(a), p1=i32(b), p2=i32(0), p3=i32(0)
        )
    );
}

def key(app: App, code: int) {
    event(2, code);
    assert app.step();
    event(1, code);
    assert app.step();
}

def click(app: App, x: int, y: int) {
    event(7, x, y);
    event(6, 0);
    assert app.step();
    event(5, 0);
    assert app.step();
}
