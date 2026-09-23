import from engine.world.clocks { Clock, HasClock, Readout, Glyph, Spells, Shows, ClockTick, clock_text, glyph_frame }
import from engine.world.world { World }
import from engine.world.signals { Signal, Targets }
import from engine.formats.bsp { Bsp, Face }

test "Q2 clocks count down into their readout glyphs and fire when they run out" {
    assert clock_text(0, 5) == " 5" and clock_text(1, 65) == " 1:05" and clock_text(2, 3725) == " 1:02:05";
    assert glyph_frame(" 1:05", 3) == 11 and glyph_frame(" 1:05", 5) == 5 and glyph_frame(" 1:05", 1) == 12;
    world = World();
    bsp = Bsp(game="q2");
    bsp.faces = [Face(), Face(), Face()];
    readout = Readout();
    tens = Glyph(position=1, faces=[0]);
    ones = Glyph(position=2, faces=[1, 2]);
    readout +>:Spells:+> tens;
    readout +>:Spells:+> ones;
    alarm = Signal();
    clock = Clock(counting_down=True, count=12, value=12, limit=0, running=True, clock=1.0, activation=Signal(entities=[1]));
    clock.activation +>:Targets:+> alarm;
    clock +>:Shows:+> readout;
    world +>:HasClock:+> clock;
    world spawn ClockTick(bsp=bsp, dt=1.0);
    assert readout.message == "12" and bsp.faces[0].frame == 1 and bsp.faces[2].frame == 2;
    for second in range(12) {
        world spawn ClockTick(bsp=bsp, dt=1.0);
    }
    assert readout.message == " 0" and bsp.faces[1].frame == 0 and bsp.faces[0].frame == 12;
    assert not clock.running and alarm.pending == 1;
}
