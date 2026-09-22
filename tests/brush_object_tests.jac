import from engine.world.brushes {
    BrushObject,
    HasBrush,
    BrushTick,
    ShootBrush,
    load_brushes
}
import from engine.world.world { Player }
import from engine.world.combat { CombatState, Opponent, HasOpponent }
import from engine.world.signals { Signal, Targets, Fire }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.door_support { DoorFixture, pair_fixture }

test "toggle walls switch rendering and world collision together" {
    f = DoorFixture();
    f.setup("q2", {"classname": "func_wall", "spawnflags": "3"});
    load_brushes(f.world, f.bsp, f.collision);
    brush = [f.world->:HasBrush:->][?:BrushObject][0];
    player = Player(pos=Vec3(x=1000.0));
    state = CombatState();
    assert not brush.active and f.bsp.faces[0].hidden;
    assert f.collision.trace_point(
        Vec3(x=-100.0, z=40.0), Vec3(x=100.0, z=40.0)
    ).fraction
        == 1.0;
    brush.activation spawn Fire(emit=False);
    f.world spawn BrushTick(
        bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert brush.active and not f.bsp.faces[0].hidden;
    assert f.collision.trace_point(
        Vec3(x=-100.0, z=40.0), Vec3(x=100.0, z=40.0)
    ).fraction
        < 1.0;
    brush.activation spawn Fire(emit=False);
    f.world spawn BrushTick(
        bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert not brush.active and f.bsp.faces[0].hidden;
}

test "destructible brush damage removes geometry emits targets and restores" {
    f = DoorFixture();
    f.setup("q2", {"classname": "func_explosive"});
    load_brushes(f.world, f.bsp, f.collision);
    brush = [f.world->:HasBrush:->][?:BrushObject][0];
    player = Player(pos=Vec3(x=1000.0));
    state = CombatState();
    sink = Signal();
    brush.activation +>:Targets:+> sink;
    assert brush.health == 100;
    f.world spawn ShootBrush(
        model=1, amount=50, bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert brush.health == 50 and brush.active;
    level = Level(bsp=f.bsp, collision=f.collision, name="fixture");
    before = snapshot(f.world, level, player, state);
    f.world spawn ShootBrush(
        model=1, amount=50, bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert brush.destroyed and not brush.active and sink.pending == 1;
    assert f.bsp.faces[0].hidden and 0 in f.collision.disabled;
    f.world spawn ShootBrush(
        model=1, amount=50, bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert sink.pending == 1;
    restore(f.world, level, player, state, before);
    assert not brush.destroyed and brush.active and brush.health == 50;
    assert not f.bsp.faces[0].hidden and 0 not in f.collision.disabled;
}

test "brush explosions use shared opponent death effects and credit direct shots" {
    f = DoorFixture();
    f.setup("q2", {"classname": "func_explosive", "dmg": "200"});
    load_brushes(f.world, f.bsp, f.collision);
    player = Player(pos=Vec3(x=1000.0));
    state = CombatState();
    enemy = Opponent(pos=Vec3(x=100.0, z=22.0), health=60);
    f.world +>:HasOpponent:+> enemy;
    sink = Signal();
    enemy.activation +>:Targets:+> sink;
    f.world spawn ShootBrush(
        model=1,
        amount=100,
        bsp=f.bsp,
        collision=f.collision,
        player=player,
        state=state
    );
    assert enemy.health == 0
        and not enemy.visual.visible
        and state.kills == 1
        and sink.pending == 1;
}

test "trigger spawned explosives must appear before taking damage" {
    f = DoorFixture();
    f.setup(
        "q2", {"classname": "func_explosive", "spawnflags": "1", "targetname": "spawn"}
    );
    load_brushes(f.world, f.bsp, f.collision);
    brush = [f.world->:HasBrush:->][?:BrushObject][0];
    player = Player(pos=Vec3(x=1000.0));
    state = CombatState();
    f.world spawn ShootBrush(
        model=1,
        amount=100,
        bsp=f.bsp,
        collision=f.collision,
        player=player,
        state=state
    );
    assert brush.health == 100 and not brush.active;
    brush.activation spawn Fire(emit=False);
    f.world spawn BrushTick(
        bsp=f.bsp, collision=f.collision, player=player, state=state
    );
    assert brush.active and not brush.usable;
    f.world spawn ShootBrush(
        model=1,
        amount=100,
        bsp=f.bsp,
        collision=f.collision,
        player=player,
        state=state
    );
    assert brush.destroyed;
}

test "explosive brushes chain without reprocessing destroyed neighbors" {
    f = pair_fixture("q2");
    for entity in f.bsp.entities {
        entity.fields["classname"] = "func_explosive";
        entity.fields["dmg"] = "200";
    }
    load_brushes(f.world, f.bsp, f.collision);
    f.world spawn ShootBrush(
        model=1,
        amount=100,
        bsp=f.bsp,
        collision=f.collision,
        player=Player(pos=Vec3(x=1000.0)),
        state=CombatState()
    );
    for brush in [f.world->:HasBrush:->][?:BrushObject] {
        assert brush.destroyed and not brush.active;
    }
    assert len(f.collision.disabled) == 2;
}
