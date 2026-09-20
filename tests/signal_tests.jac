import from engine.world.signals { Signal, Targets, Fire }

test "activation relays fan out once through cycles" {
    source = Signal();
    relay = Signal(relay=True);
    other = Signal(relay=True);
    destination = Signal();
    source +>:Targets:+> relay;
    relay +>:Targets:+> other;
    other +>:Targets:+> relay;
    relay +>:Targets:+> destination;
    other +>:Targets:+> destination;
    source spawn Fire();
    assert destination.pending == 1;
    source spawn Fire();
    assert destination.pending == 2;
}
