import from engine.world.hazards { Hazard, HasHazard, HazardTick, load_hazards }
import from engine.world.world { Player }
import from engine.world.signals { Fire }
import from engine.world.level { Level }
import from engine.world.combat { CombatState, Opponent, HasOpponent }
import from engine.core.savegame { snapshot, restore }
import from engine.math.vec3 { Vec3 }
import from tests.trigger_support { trigger_fixture }

test "authored hurt volumes catch crossings and obey cooldown" {
    for game in ["q2", "q3"] {
        f = trigger_fixture(game);
        f.bsp.entities[1].fields["classname"] = "trigger_hurt";
        f.bsp.entities[1].fields["dmg"] = "10";
        load_hazards(f.world, f.bsp);
        hazards = [f.world->:HasHazard:->][?:Hazard];
        assert len(hazards) == 1;
        player = Player();
        f.world spawn HazardTick(
            player=player, start=Vec3(x=160.0), finish=Vec3(x=240.0), dt=0.01
        );
        assert player.health == 90;
        f.world spawn HazardTick(
            player=player, start=Vec3(x=190.0), finish=Vec3(x=190.0), dt=0.05
        );
        assert player.health == 90;
        f.world spawn HazardTick(
            player=player, start=Vec3(x=190.0), finish=Vec3(x=190.0), dt=0.05
        );
        assert player.health == 80;
        f.world spawn HazardTick(
            player=player,
            start=Vec3(x=190.0),
            finish=Vec3(x=190.0),
            dt=1.0,
            touching=False
        );
        assert player.health == 80;
    }
}

test "hazard toggle slow damage and persistence preserve authored state" {
    f = trigger_fixture();
    f.bsp.entities[1].fields["classname"] = "trigger_hurt";
    f.bsp.entities[1].fields["spawnflags"] = "19";
    load_hazards(f.world, f.bsp);
    hazard = [f.world->:HasHazard:->][?:Hazard][0];
    player = Player();
    state = CombatState();
    level = Level(bsp=f.bsp, collision=f.collision, name="fixture");
    assert not hazard.enabled and hazard.interval == 1.0;
    hazard.activation spawn Fire(emit=False);
    f.world spawn HazardTick(
        player=player, start=Vec3(x=190.0), finish=Vec3(x=190.0), dt=0.1
    );
    assert hazard.enabled and player.health == 95;
    data = snapshot(f.world, level, player, state);
    hazard.activation spawn Fire(emit=False);
    f.world spawn HazardTick(
        player=player, start=Vec3(x=190.0), finish=Vec3(x=190.0), dt=0.1
    );
    assert not hazard.enabled;
    restore(f.world, level, player, state, data);
    assert hazard.enabled and hazard.cooldown == 1.0 and player.health == 95;
}

test "hazards use armor normally bypass it when authored and retain god mode" {
    for flags in [0, 8] {
        for god in [False, True] {
            f = trigger_fixture();
            f.bsp.entities[1].fields["classname"] = "trigger_hurt";
            f.bsp.entities[1].fields["spawnflags"] = str(flags);
            f.bsp.entities[1].fields["dmg"] = "10";
            load_hazards(f.world, f.bsp);
            player = Player(armor=50, armor_ratio=0.5, god_mode=god);
            f.world spawn HazardTick(
                player=player, start=Vec3(x=190.0), finish=Vec3(x=190.0), dt=0.1
            );
            assert player.health == (100 if god else (90 if flags == 8 else 95));
            assert player.armor == (50 if god or flags == 8 else 45);
        }
    }
}

test "arena bots take damage from death volumes without requiring player contact" {
    f = trigger_fixture("q3");
    f.bsp.entities[1].fields["classname"] = "trigger_hurt";
    f.bsp.entities[1].fields["dmg"] = "1000";
    load_hazards(f.world, f.bsp);
    enemy = Opponent(pos=Vec3(x=190.0, z=22.0), arena=True);
    f.world +>:HasOpponent:+> enemy;
    f.world spawn HazardTick(
        player=Player(), start=Vec3(), finish=Vec3(), dt=0.1, touching=False
    );
    assert enemy.health == 0 and not enemy.visual.visible and enemy.respawn_wait == 3.0;
}
