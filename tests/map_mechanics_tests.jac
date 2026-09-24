import from engine.world.signals { Signal, HasSignal, Targets, Kills, Fire, counter_text }
import from engine.world.triggers {
    TouchTrigger,
    HasTrigger,
    Activates,
    TriggerTick,
    ShootTrigger,
    MonsterJump,
    HasMonsterJump,
    MonsterJumpTick,
    load_triggers
}
import from engine.world.doors { Door, HasDoor, authored_cue }
import from engine.world.shooters { Shooter, HasShooter, ShooterTick, load_shooters, move_direction }
import from engine.world.fixtures { Fixture, HasFixture, FixtureTick }
import from engine.world.targets { TargetEvent, HasTarget, TargetTick, HasHelp, HelpComputer }
import from engine.world.inventory { quantity, CopyInventory, AdjustInventory }
import from engine.world.powerups { GrantPowerup, powerup_left }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.combat { Opponent, HasOpponent, Projectile, HasProjectile, ProjectileTick, CombatState }
import from engine.world.traversal { Traversal, HasTraversal, TraversalTick, Destination, ArrivesAt }
import from engine.world.world { World, Player }
import from engine.world.opponent_rule { OpponentRule }
import from engine.formats.bsp { Bsp, MapEntity }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }
import from games.fixtures { fixture_rule }
import from games.enemies { enemy_rule }
import from tests.trigger_support { trigger_fixture, touch }
import from tests.traversal_tests { traversal_box }

def box_volume() -> CollisionMap {
    volume = CollisionMap();
    volume.add_box(
        Vec3(x=-32.0, y=-32.0, z=-32.0),
        Vec3(x=32.0, y=32.0, z=32.0),
        Vec3(),
        Vec3(),
        Vec3()
    );
    volume.reindex();
    return volume;
}

test "directional triggers only fire for players facing along them" {
    fixture = trigger_fixture();
    # InitTrigger: angle 0 means no facing; 90 requires facing +Y.
    fixture.bsp.entities[1].fields["angle"] = "90";
    fixture.bsp.entities[1].fields["message"] = "Onward";
    fixture.bsp.entities[1].fields["sounds"] = "2";
    load_triggers(fixture.world, fixture.bsp);
    trigger = [fixture.world->:HasTrigger:->][?:TouchTrigger][0];
    door = [fixture.world->:HasDoor:->][?:Door][0];
    point = Vec3(x=200.0, z=24.0);
    away = Player(yaw=-1.5708);
    fixture.world spawn TriggerTick(start=point, finish=point, dt=0.01, player=away);
    assert trigger.activations == 0;
    toward = Player(yaw=1.5708);
    result = fixture.world spawn TriggerTick(start=point, finish=point, dt=0.01, player=toward);
    assert trigger.activations == 1 and door.activation.pending == 1;
    assert result.message == "Onward" and result.cues == ["sound/misc/talk.wav"];
}

test "named triggers fire their targets when used and Q2 TRIGGERED ones arm first" {
    fixture = trigger_fixture();
    fixture.bsp.entities[1].fields["targetname"] = "remote";
    fixture.bsp.entities[1].fields["spawnflags"] = "4";
    load_triggers(fixture.world, fixture.bsp);
    trigger = [fixture.world->:HasTrigger:->][?:TouchTrigger][0];
    door = [fixture.world->:HasDoor:->][?:Door][0];
    relay = trigger.signal;
    assert relay is not None and relay.armable and not relay.armed;
    point = Vec3(x=200.0, z=24.0);
    touch(fixture, point, point);
    assert trigger.activations == 0 and door.activation.pending == 0;
    relay spawn Fire(emit=False);
    assert relay.armed and door.activation.pending == 0;
    touch(fixture, point, point);
    assert trigger.activations == 1 and door.activation.pending == 1;
    relay spawn Fire(emit=False);
    assert door.activation.pending == 2;
}

test "killtargets retire their victims and messages need a player activator" {
    source = Signal(relay=True, message="Gone", cue="sound/misc/trigger1.wav");
    victim = Signal(relay=True);
    output = Signal();
    victim +>:Targets:+> output;
    source +>:Kills:+> victim;
    quiet = source spawn Fire(emit=False);
    assert victim.killed and not victim.enabled and quiet.message == "";
    assert quiet.cues == ["sound/misc/trigger1.wav"];
    victim spawn Fire(emit=False);
    assert output.pending == 0;
    world = World();
    speaker_signal = Signal(entities=[3]);
    world +>:HasSignal:+> speaker_signal;
    assert counter_text("q1", 5) == "There are more to go...";
    assert counter_text("q1", 2) == "Only 2 more to go...";
    assert counter_text("q2", 3) == "3 more to go..." and counter_text("silent", 3) == "";
    assert authored_cue("q2", "trigger_relay", {"message": "hi"}) == "sound/misc/talk1.wav";
    assert authored_cue("q1", "trigger_secret", {}) == "sound/misc/secret.wav";
    assert authored_cue("q2", "target_secret", {}) == "sound/misc/secret.wav";
}

test "shootable triggers take damage then fire once and stop blocking" {
    world = World();
    collision = CollisionMap();
    collision.add_box(Vec3(x=-8.0, y=-8.0, z=-8.0), Vec3(x=8.0, y=8.0, z=8.0), Vec3(), Vec3(), Vec3());
    collision.models = [5];
    collision.reindex();
    relay = Signal(relay=True, once=True);
    output = Signal();
    relay +>:Targets:+> output;
    trigger = TouchTrigger(
        model=5,
        volume=box_volume(),
        interval=0.2,
        once=True,
        signal=relay,
        touchable=False,
        health=10,
        max_health=10,
        hulls=[0]
    );
    trigger +>:Activates:+> relay;
    world +>:HasTrigger:+> trigger;
    world spawn ShootTrigger(model=5, amount=4, collision=collision);
    assert trigger.health == 6 and output.pending == 0;
    world spawn ShootTrigger(model=5, amount=8, collision=collision);
    assert output.pending == 1 and not trigger.enabled;
    assert collision.trace(Vec3(), Vec3()).start_solid == False;
    world spawn ShootTrigger(origin=Vec3(x=10.0), amount=100, radius=120.0, collision=collision);
    assert output.pending == 1;
}

test "monster jump triggers launch grounded walkers along their angle" {
    world = World();
    world +>:HasMonsterJump:+> MonsterJump(volume=box_volume(), push=Vec3(x=300.0), height=250.0);
    walker_enemy = Opponent(health=50, grounded=True, pos=Vec3(z=22.0), eye_height=22.0);
    flier = Opponent(health=50, grounded=True, pos=Vec3(z=22.0), eye_height=22.0, rule=OpponentRule(movement="fly"));
    world +>:HasOpponent:+> walker_enemy;
    world +>:HasOpponent:+> flier;
    result = world spawn MonsterJumpTick();
    assert result.launched == 1 and walker_enemy.velocity.x == 300.0;
    assert walker_enemy.velocity.z == 250.0 and not walker_enemy.grounded;
    assert flier.velocity.length() == 0.0;
}

test "trap shooters launch world projectiles that hurt players and monsters" {
    bsp = Bsp(
        game="q1",
        entities=[
            MapEntity(fields={"classname": "trap_spikeshooter", "origin": "0 0 0", "angle": "0", "spawnflags": "1"}),
            MapEntity(fields={"classname": "trap_shooter", "origin": "0 64 0", "angle": "-1", "wait": "0.5"}),
            MapEntity(fields={"classname": "misc_fireball", "origin": "0 0 -64"})
        ]
    );
    world = World();
    load_shooters(world, bsp);
    shooters = [world->:HasShooter:->][?:Shooter];
    assert len(shooters) == 3 and shooters[0].kind == "superspike";
    assert shooters[1].direction.z == 1.0 and shooters[1].interval == 0.5;
    assert shooters[0].speaker is not None;
    shooters[0].activation.pending = 1;
    first = world spawn ShooterTick(dt=0.01);
    missiles = [world->:HasProjectile:->][?:Projectile];
    assert first.fired == 1 and missiles[0].damage == 18 and missiles[0].trap;
    assert missiles[0].velocity.x == 500.0;
    later = world spawn ShooterTick(dt=6.0);
    assert later.fired >= 2;
    assert move_direction({"mangle": "90 0 0"}).z < -0.99;
    target_world = World();
    enemy = Opponent(health=30, pos=Vec3(x=100.0, z=22.0), eye_height=22.0);
    target_world +>:HasOpponent:+> enemy;
    target_world +>:HasProjectile:+> Projectile(pos=Vec3(z=16.0), velocity=Vec3(x=500.0), damage=9, hostile=True, trap=True);
    player = Player(health=100, pos=Vec3(x=-500.0, z=22.0));
    target_world spawn ProjectileTick(player=player, collision=CollisionMap(), state=CombatState(), dt=0.5);
    assert enemy.health == 21 and player.health == 100;
}

test "fixtures animate their original frames and barrels explode on death" {
    torch = fixture_rule("q1", "light_torch_small_walltorch", 0);
    assert torch is not None and torch.model == "progs/flame.mdl" and torch.group == 0;
    assert torch.sound == "sound/ambience/fire1.wav" and torch.volume == 0.5;
    body = fixture_rule("q2", "misc_deadsoldier", 8);
    assert body is not None and body.frames == [3];
    swamp = fixture_rule("q1", "ambient_swamp2", 0);
    assert swamp is not None and swamp.sound == "sound/ambience/swamp2.wav";
    world = World();
    banner = Fixture(frames=[4, 5, 6]);
    world +>:HasFixture:+> banner;
    world spawn FixtureTick(dt=0.15);
    assert banner.visual.first == 5 and banner.visual.second == 6;
    barrel = enemy_rule("q1", "misc_explobox");
    assert barrel is not None and barrel.inert and barrel.death_splash == 160;
    crate = enemy_rule("q2", "misc_explobox");
    assert crate is not None and crate.health == 10;
}

test "named Q1 teleporters work only just after they are used" {
    world = World();
    portal = Traversal(volume=traversal_box(), kind="teleport", gated=True);
    portal +>:ArrivesAt:+> Destination(origin=Vec3(x=900.0));
    world +>:HasTraversal:+> portal;
    player = Player(pos=Vec3(z=22.0));
    world spawn TraversalTick(player=player, collision=CollisionMap(), start=Vec3(), dt=0.01);
    assert player.pos.x == 0.0;
    portal.activation.pending = 1;
    world spawn TraversalTick(player=player, collision=CollisionMap(), start=Vec3(), dt=0.01);
    assert player.pos.x == 900.0;
    portal.activation.killed = True;
    player.pos = Vec3(z=22.0);
    player.teleport_cooldown = 0.0;
    portal.activation.pending = 1;
    world spawn TraversalTick(player=player, collision=CollisionMap(), start=Vec3(), dt=0.01);
    assert player.pos.x == 0.0;
}

test "Q2 targets explode, quake, update the help computer and fire lasers" {
    world = World();
    player = Player(health=100, pos=Vec3(x=64.0, z=22.0), grounded=True);
    state = CombatState(game="q2");
    blast = TargetEvent(kind="explosion", origin=Vec3(), damage=50);
    quake = TargetEvent(kind="earthquake", count=2, speed=200.0);
    help = TargetEvent(kind="help", message="Find the data CD", primary=True);
    beam = TargetEvent(kind="laser", origin=Vec3(x=-200.0, z=22.0), direction=Vec3(x=1.0), damage=5);
    for event in [blast, quake, help, beam] {
        world +>:HasTarget:+> event;
        event.activation.pending = 1;
    }
    result = world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.05);
    assert player.health < 100 and player.health > 50;
    assert state.impacts and state.impacts[0].splash == 50;
    assert result.message == "Help computer updated (F1)" and "sound/misc/pc_up.wav" in result.cues;
    computers = [world->:HasHelp:->][?:HelpComputer];
    assert computers[0].primary == "Find the data CD";
    assert beam.on and quake.remaining > 0.0 and not player.grounded;
    before = player.health;
    player.grounded = True;
    world spawn TargetTick(player=player, collision=CollisionMap(), state=state, dt=0.2);
    assert player.health == before - 5;
}

test "cross-level flags persist through a unit and gate their targets" {
    player = Player();
    grant = Signal(relay=True, grant_flags=5);
    grant spawn Fire(emit=False, inventory=player.inventory);
    assert quantity(player.inventory, "unit_flags") == 5;
    output = Signal();
    waiting = Signal(require_flags=4);
    waiting +>:Targets:+> output;
    waiting spawn Fire(inventory=player.inventory);
    assert output.pending == 1;
    strict = Signal(require_flags=2);
    strict +>:Targets:+> output;
    strict spawn Fire(inventory=player.inventory);
    assert output.pending == 1;
    carried = player.inventory spawn CopyInventory(skip_flags=True);
    assert quantity(carried.result, "unit_flags") == 0;
    # Keys survive a single-player unit change; only Q1 strips them.
    player.inventory spawn AdjustInventory(kind="key_data_cd", amount=1);
    unit = player.inventory spawn CopyInventory(skip_flags=True);
    assert quantity(unit.result, "key_data_cd") == 1;
    level = player.inventory spawn CopyInventory(skip_keys=True);
    assert quantity(level.result, "key_data_cd") == 0;
    assert quantity(level.result, "unit_flags") == 5;
    kept = player.inventory spawn CopyInventory();
    assert quantity(kept.result, "unit_flags") == 5;
}

test "Q3 remove_powerups strips timed powerups and print shows its message" {
    world = World();
    player = Player(health=100);
    player spawn GrantPowerup(kind="quad", duration=30.0);
    strip = TargetEvent(kind="remove_powerups");
    note = TargetEvent(kind="print", message="Frag them all");
    for event in [strip, note] {
        world +>:HasTarget:+> event;
        event.activation.pending = 1;
    }
    result = world spawn TargetTick(player=player, collision=CollisionMap(), state=CombatState(), dt=0.01);
    assert powerup_left(player, "quad") == 0.0 and result.message == "Frag them all";
}

test "Q3 target_give hands over its targeted items without placing them" {
    world = World();
    player = Player(health=100);
    armor = Pickup(
        rule=PickupRule(kind="armor", amount=50, capacity=200, model="", armor_mode="add", armor_ratio=0.66),
        active=False,
        waiting_for_use=True,
        activation=Signal(entities=[7])
    );
    world +>:HasPickup:+> armor;
    gift = TargetEvent(kind="give", gifts=[7]);
    world +>:HasTarget:+> gift;
    gift.activation.pending = 1;
    world spawn TargetTick(player=player, collision=CollisionMap(), state=CombatState(), dt=0.01);
    assert player.armor == 50 and armor.waiting_for_use and not armor.visual.visible;
}
