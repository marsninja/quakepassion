import from engine.core.savegame { snapshot, restore }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState, Projectile, HasProjectile, Opponent, HasOpponent }
import from engine.world.pickups { Pickup, PickupRule, HasPickup }
import from engine.world.hazards { Hazard, HasHazard }
import from engine.world.speakers { Speaker, HasSpeaker }
import from engine.world.triggers { TouchTrigger, HasTrigger }
import from engine.world.signals { progress_for }
import from engine.world.shooters { Shooter, HasShooter }
import from engine.world.rotators { Rotator, HasRotator }
import from engine.world.arena { ArenaMatch, HasMatch, Competes }
import from engine.world.powerups { GrantPowerup, powerup_left }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

test "every snapshot record type restores alongside all the others" {
    world = World();
    world +>:HasPickup:+> Pickup(rule=PickupRule(kind="shells", amount=1, capacity=9, model=""));
    world +>:HasHazard:+> Hazard(volume=CollisionMap(), cooldown=0.25);
    world +>:HasSpeaker:+> Speaker(path="sound/a.wav", origin=Vec3(), looping=True, playing=True);
    world +>:HasTrigger:+> TouchTrigger(model=1, volume=CollisionMap(), interval=0.2, cooldown=0.1);
    record = progress_for(world);
    record.total_secrets = 2;
    record.secrets = 1;
    world +>:HasShooter:+> Shooter(origin=Vec3(), clock=0.75, random_state=11);
    world +>:HasRotator:+> Rotator(model=1, clock=2.5);
    world +>:HasProjectile:+> Projectile(pos=Vec3(), velocity=Vec3(x=1.0), damage=9, hostile=True, trap=True);
    bot = Opponent(arena=True, health=100);
    world +>:HasOpponent:+> bot;
    contest = ArenaMatch(fraglimit=9);
    world +>:HasMatch:+> contest;
    contest +>:Competes:name="Ranger":+> bot;
    player = Player(health=90);
    contest +>:Competes:name="You", human=True:+> player;
    player spawn GrantPowerup(kind="quad", duration=12.0);
    scores = [edge contest->:Competes:->];
    scores[0].frags = 3;
    level = Level();
    level.name = "test";
    data = snapshot(world, level, player, CombatState());
    tags = [line.split()[0] for line in data.splitlines()[3:]];
    for tag in ["TRAP", "SHOOTER", "MOVER", "MATCH", "SCORE", "POWER", "P", "H", "A", "T", "O"] {
        assert tag in tags;
    }
    scores[0].frags = 0;
    restore(world, level, player, CombatState(), data);
    assert scores[0].frags == 3 and powerup_left(player, "quad") == 12.0;
    assert [world->:HasRotator:->][?:Rotator][0].clock == 2.5;
    assert [world->:HasShooter:->][?:Shooter][0].random_state == 11;
    restored = [world->:HasProjectile:->][?:Projectile];
    assert len(restored) == 1 and restored[0].trap and restored[0].hostile;
}
