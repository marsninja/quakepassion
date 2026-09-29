import math;
import from engine.world.chthon {
    ChthonTick,
    LightningEvent,
    HasLightning,
    Electrode,
    BOSS_RISE,
    BOSS_MISSILE,
    BOSS_SHOCKA,
    BOSS_IDLE,
    BOSS_GONE
}
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
import from engine.world.speakers { Speaker }
import from engine.world.particles { ShotTrail, HasTrail }
import from engine.world.level { Level }
import from engine.math.vec3 { Vec3 }
import from engine.math.aabb { AABB }
import from games.enemies { enemy_rule }
import from games.opponents { register_speaker }
import from engine.core.savegame { snapshot, restore }

obj ChthonFixture {
    has world: World = World(),
        player: Player = Player(pos=Vec3(x=800.0)),
        state: CombatState = CombatState(),
        boss: Opponent = Opponent(),
        event: LightningEvent = LightningEvent(activation=Signal()),
        power: Speaker = Speaker(path="sound/misc/power.wav", origin=Vec3()),
        doors: list[Door] = [];

    def setup(skill: int = 1) {
        rule = enemy_rule("q1", "monster_boss");
        assert rule is not None;
        self.boss = Opponent(rule=rule, health=3, max_health=3, dormant=True, skill=skill);
        self.world +>:HasOpponent:+> self.boss;
        self.world +>:HasSignal:+> self.boss.activation;
        for path in [rule.sight_sound, rule.death_sound, rule.attack_sound] + rule.pain_sounds + rule.sounds {
            register_speaker(self.world, self.boss, path);
        }
        self.event.speaker = self.power;
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

    def heard(path: str) -> int {
        for i in range(len(self.boss.speaker_paths)) {
            if self.boss.speaker_paths[i] == path {
                return self.boss.speakers[i].requests;
            }
        }
        return -1;
    }
}

test "Chthon requires activation and rejects weapon damage while throwing original missiles" {
    f = ChthonFixture();
    f.setup();
    f.tick(1.0);
    assert f.boss.dormant;
    f.boss.activation.pending = 1;
    f.tick(0.01);
    assert not f.boss.dormant and f.boss.boss_phase == BOSS_RISE;
    assert damage_opponent(f.boss, 1000) == 0 and f.boss.health == 3;
    for i in range(450) {
        f.tick();
    }
    shots = [f.world->:HasProjectile:->][?:Projectile];
    assert len(shots) == 2;
    for shot in shots {
        assert shot.hostile and shot.effect == "q1_lavaball" and shot.owner is f.boss;
        assert abs(shot.velocity.length() - 300.0) < 0.00001;
        # T_MissileTouch: 100 + random() * 20.
        assert shot.damage >= 100 and shot.damage < 120;
    }
}

test "Chthon plays boss.qc's sounds and skill sets its health" {
    f = ChthonFixture();
    f.setup();
    f.boss.activation.pending = 1;
    f.tick();
    # boss_rise1: out1 as it breaks the surface, boss_rise2: sight1.
    assert f.heard("sound/boss1/out1.wav") == 1 and f.heard("sound/boss1/sight1.wav") == 0;
    f.tick(0.1);
    assert f.heard("sound/boss1/sight1.wav") == 1;
    # boss_missile9 and 20 throw.
    f.tick(1.6);
    assert f.boss.boss_phase == BOSS_MISSILE;
    f.tick(0.8);
    assert f.heard("sound/boss1/throw.wav") == 1;
    for door in f.doors {
        door.state = "open";
    }
    f.event.activation.pending = 1;
    f.tick();
    assert f.heard("sound/boss1/pain.wav") == 1 and f.power.requests == 1;
    assert f.boss.boss_phase == BOSS_SHOCKA;
    easy = ChthonFixture();
    easy.setup(0);
    easy.boss.activation.pending = 1;
    easy.tick();
    assert easy.boss.health == 1;
}

test "Chthon turns at its yaw speed and leads the player above Normal" {
    f = ChthonFixture();
    f.setup(2);
    f.player.pos = Vec3(y=800.0, z=22.0);
    f.boss.activation.pending = 1;
    f.tick(1.69);
    # The rise does not turn it; each boss_face turns 20 degrees.
    assert f.boss.yaw == 0.0 and f.boss.boss_phase == BOSS_RISE;
    f.tick(0.01);
    assert f.boss.boss_phase == BOSS_MISSILE;
    assert abs(math.degrees(f.boss.yaw) - 20.0) < 0.001;
    f.tick(0.1);
    assert abs(math.degrees(f.boss.yaw) - 40.0) < 0.001;
    # On Hard the ball flies at where the player's ground speed will take it.
    f.player.velocity = Vec3(x=200.0, z=-50.0);
    f.tick(0.7);
    shot = [f.world->:HasProjectile:->][?:Projectile][0];
    assert shot.velocity.x > 30.0;
    level = ChthonFixture();
    level.setup(1);
    level.player.pos = Vec3(y=800.0, z=22.0);
    level.player.velocity = Vec3(x=200.0);
    level.boss.activation.pending = 1;
    level.tick(1.7);
    level.tick(0.8);
    normal = [level.world->:HasProjectile:->][?:Projectile][0];
    assert normal.velocity.x < shot.velocity.x;
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
        # Uses in the same tick as the bolt starts are one use.
        f.event.activation.pending = 2;
        f.tick();
        assert f.boss.health == expected;
        # lightning_fire: a bolt every tenth of a second, 100 units short.
        trails = [f.world->:HasTrail:->][?:ShotTrail];
        assert trails and trails[-1].kind == "q1_lightning3";
        for i in range(110) {
            f.tick();
        }
        assert f.doors[0].state == "closing";
    }
    for i in range(200) {
        f.tick();
    }
    assert f.boss.boss_phase == BOSS_GONE and not f.boss.visual.visible;
    assert sink.pending == 1 and f.state.kills == 1;
    assert f.heard("sound/boss1/death.wav") == 1;
    for i in range(300) {
        f.tick();
    }
    assert sink.pending == 1 and f.state.kills == 1;
}

test "Chthon idles over a dead player and throws again at a living one" {
    f = ChthonFixture();
    f.setup();
    f.boss.activation.pending = 1;
    f.tick(1.7);
    f.player.health = 0;
    f.tick(0.8);
    assert f.boss.boss_phase == BOSS_IDLE;
    f.player.health = 100;
    f.tick(3.1);
    assert f.boss.boss_phase == BOSS_MISSILE;
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
    assert f.boss.health == 2 and f.boss.boss_phase == BOSS_SHOCKA;
    assert abs(f.boss.boss_time - 0.25) < 0.000001 and f.event.remaining == 1.0;
    assert f.boss.visual.visible;
    f.tick(1.0);
    assert f.event.remaining == 0.0 and f.doors[0].state == "closing";
}
