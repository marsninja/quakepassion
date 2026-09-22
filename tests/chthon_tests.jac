import from engine.world.chthon { ChthonTick, LightningEvent, HasLightning, Electrode }
import from engine.world.combat {
    Opponent,
    HasOpponent,
    CombatState,
    damage_opponent,
    HasProjectile,
    Projectile
}
import from engine.world.world { World, Player }
import from engine.world.doors { Door, HasDoor }
import from engine.world.signals { Signal, HasSignal, Targets }
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from games.enemies { enemy_rule }
import from engine.core.savegame { snapshot, restore }

obj ChthonFixture {
    has world: World = World(),
        player: Player = Player(pos=Vec3(x=800.0)),
        state: CombatState = CombatState(),
        boss: Opponent = Opponent(),
        event: LightningEvent = LightningEvent(activation=Signal()),
        doors: list[Door] = [];

    def setup() {
        rule = enemy_rule("q1", "monster_boss");
        assert rule is not None;
        self.boss = Opponent(rule=rule, health=3, max_health=3, dormant=True);
        self.world +>:HasOpponent:+> self.boss;
        self.world +>:HasSignal:+> self.boss.activation;
        self.world +>:HasLightning:+> self.event;
        self.world +>:HasSignal:+> self.event.activation;
        for model in [1, 2] {
            door = Door(
                model=model,
                trigger=AABB(mins=Vec3(), maxs=Vec3()),
                travel=Vec3(z=100.0),
                speed=100.0,
                hold_time=3.0
            );
            self.doors.append(door);
            self.world +>:HasDoor:+> door;
            self.event +>:Electrode:+> door;
        }
    }

    def tick(dt: float = 0.01) {
        self.world spawn ChthonTick(player=self.player, state=self.state, dt=dt);
    }
}

test "Chthon requires activation and rejects weapon damage while throwing original missiles" {
    f = ChthonFixture();
    f.setup();
    f.tick(1.0);
    assert f.boss.dormant;
    f.boss.activation.pending = 1;
    f.tick(0.01);
    assert not f.boss.dormant and f.boss.boss_phase == 1;
    assert damage_opponent(f.boss, 1000) == 0 and f.boss.health == 3;
    for i in range(450) {
        f.tick();
    }
    shots = [f.world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 2;
    for shot in shots {
        assert shot.hostile and shot.effect == "q1_lavaball";
        assert abs(shot.velocity.length() - 300.0) < 0.00001;
    }
}

test "unaligned electrodes do no damage and three aligned strikes finish the boss once" {
    f = ChthonFixture();
    f.setup();
    sink = Signal();
    f.boss.activation +>:Targets:+> sink;
    f.boss.activation.pending = 1;
    f.tick(1.7);
    f.doors[0].state = "open";
    f.event.activation.pending = 1;
    f.tick();
    assert f.boss.health == 3 and f.event.remaining == 0.0;
    for expected in [2, 1, 0] {
        for door in f.doors {
            door.state = "open";
            door.position = 1.0;
        }
        f.event.activation.pending = 1;
        f.tick();
        assert f.boss.health == expected;
        f.event.activation.pending = 1;
        f.tick();
        assert f.boss.health == expected;
        for i in range(110) {
            f.tick();
        }
        assert f.doors[0].state == "closing";
    }
    for i in range(200) {
        f.tick();
    }
    assert f.boss.boss_phase == 7 and not f.boss.visual.visible;
    assert sink.pending == 1 and f.state.kills == 1;
    for i in range(300) {
        f.tick();
    }
    assert sink.pending == 1 and f.state.kills == 1;
}

test "save restores Chthon's animation phase and an active lightning interval" {
    f = ChthonFixture();
    f.setup();
    f.boss.activation.pending = 1;
    f.tick(1.7);
    for door in f.doors {
        door.state = "open";
        door.position = 1.0;
    }
    f.event.activation.pending = 1;
    f.tick(0.25);
    level = Level();
    saved = snapshot(f.world, level, f.player, f.state);
    f.tick(1.0);
    restore(f.world, level, f.player, f.state, saved);
    assert f.boss.health == 2 and f.boss.boss_phase == 3;
    assert f.boss.boss_time == 0.25 and f.event.remaining == 1.0;
    assert f.boss.visual.visible;
    f.tick(1.0);
    assert f.event.remaining == 0.0 and f.doors[0].state == "closing";
}
