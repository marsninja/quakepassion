import from engine.core.savegame { snapshot, restore }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.world.combat { CombatState, Projectile, HasProjectile, Opponent, HasOpponent, arm_bot }
import from engine.world.bot_character { BotCharacter }
import from engine.world.inventory { quantity, AdjustInventory }
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
    bot = Opponent(arena=True, health=100, character=BotCharacter());
    arm_bot(bot);
    bot.inventory spawn AdjustInventory(kind="rockets", amount=7, capacity=200);
    bot.weapon_slot = 5;
    world +>:HasOpponent:+> bot;
    remains = Opponent(health=0, remains=-12, gibbed=True, patrol_wait=0.5);
    world +>:HasOpponent:+> remains;
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
    for tag in ["TRAP", "SHOOTER", "MOVER", "MATCH", "SCORE", "POWER", "CORPSE", "PATROL", "SKILL", "BOTARM", "BOTITEM", "P", "H", "A", "T", "O"] {
        assert tag in tags;
    }
    scores[0].frags = 0;
    remains.remains = 0;
    remains.gibbed = False;
    remains.patrol_wait = 0.0;
    restore(world, level, player, CombatState(), data);
    assert remains.remains == -12 and remains.gibbed and remains.patrol_wait == 0.5;
    assert quantity(bot.inventory, "rockets") == 7 and quantity(bot.inventory, "bullets") == 100;
    assert bot.weapon_slot == 5;
    assert scores[0].frags == 3 and powerup_left(player, "quad") == 12.0;
    assert [world->:HasRotator:->][?:Rotator][0].clock == 2.5;
    assert [world->:HasShooter:->][?:Shooter][0].random_state == 11;
    restored = [world->:HasProjectile:->][?:Projectile];
    assert len(restored) == 1 and restored[0].trap and restored[0].hostile;
}
