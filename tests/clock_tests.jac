import from engine.world.clocks { Clock, HasClock, Readout, Glyph, Spells, Shows, ClockTick, clock_text, glyph_frame }
import from engine.world.world { World }
import from engine.world.signals { Signal, Targets }
import from engine.formats.bsp { Bsp, Face }
import from engine.world.flyers { Flyer, HasFlyer, Bomb, HasBomb, FlyerTick }
import from engine.world.trains { TrackPoint, TrackNext, HasTrack }
import from engine.world.world { Player }
import from engine.world.combat { CombatState }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

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

test "fly-bys appear when used, fly their corners, and their bombs burst on impact" {
    world = World();
    collision = CollisionMap();
    collision.add_box(Vec3(x=-2000.0, y=-2000.0, z=-64.0), Vec3(x=2000.0, y=2000.0, z=0.0), Vec3(), Vec3(), Vec3());
    collision.reindex();
    start = TrackPoint(entity=1, name="a", origin=Vec3(z=400.0));
    finish = TrackPoint(entity=2, name="b", origin=Vec3(x=600.0, z=400.0));
    start +>:TrackNext:+> finish;
    world +>:HasTrack:+> start;
    world +>:HasTrack:+> finish;
    passed = Signal();
    finish.activation +>:Targets:+> passed;
    ship = Flyer(model="viper", speed=300.0, target="a", activation=Signal(entities=[3]));
    ship.visual.visible = False;
    world +>:HasFlyer:+> ship;
    bomb = Bomb(pos=Vec3(x=100.0, z=380.0), damage=200, activation=Signal(entities=[4]));
    world +>:HasBomb:+> bomb;
    player = Player(health=100, pos=Vec3(x=200.0, z=22.0));
    state = CombatState(game="q2");
    ship.activation.pending = 1;
    world spawn FlyerTick(player=player, collision=collision, state=state, dt=0.5);
    assert ship.running and ship.visual.visible and ship.pos.x == 0.0;
    world spawn FlyerTick(player=player, collision=collision, state=state, dt=0.5);
    assert ship.pos.x == 150.0;
    bomb.activation.pending = 1;
    for tick in range(120) {
        world spawn FlyerTick(player=player, collision=collision, state=state, dt=0.02);
    }
    assert passed.pending == 1 and not ship.running and ship.pos.x == 600.0;
    assert bomb.burst and player.health < 100;
}
