"""The rules that make a fight feel right: how readily monsters attack, what
reaches a body past a corner, what is spared on Easy, and who turns up."""
import from engine.math.vec3 { Vec3 }
import from engine.physics.collision { CollisionMap }
import from engine.formats.bsp { MapEntity }
import from engine.render.hud { crosshair_tint }
import from engine.world.world { Player }
import from engine.world.damage { Damage }
import from engine.world.opponent_rule { OpponentRule }
import from engine.world.combat { Opponent, attack_chance, blast_reaches }
import from engine.world.spawns { active_entities }

test "a Q2 monster in your face always attacks, on Easy one time in four" {
    near = Opponent(game="q2", rule=OpponentRule(), skill=1);
    assert attack_chance(near, 60.0, False) == 1.0;
    near.skill = 0;
    assert attack_chance(near, 60.0, False) == 0.25;
}

test "a fiend pounces at any range past 200 units one time in ten" {
    fiend = Opponent(game="q1", rule=OpponentRule(near_chance=1.0, pounce_chance=0.1));
    assert attack_chance(fiend, 150.0, False) == 1.0;
    assert attack_chance(fiend, 250.0, False) == 0.1;
    assert attack_chance(fiend, 900.0, False) == 0.1;
}

test "a blast reaches through open space" {
    assert blast_reaches(CollisionMap(), Vec3(), Vec3(x=100.0));
}

test "Easy's hurt scale halves a hit but never to nothing or off a telefrag" {
    player = Player(health=100, hurt_scale=0.5);
    player spawn Damage(amount=20);
    assert player.health == 90;
    player spawn Damage(amount=1);
    assert player.health == 89;
    player spawn Damage(amount=500, bypass_armor=True, bypass_protection=True);
    assert player.health <= 0;
}

test "a Q2 monster named only by its target comes when that is fired" {
    fields = {"classname": "monster_flyer", "spawnflags": "2", "target": "t20"};
    active = active_entities("q2", [MapEntity(fields=fields)]);
    assert active[0].fields["targetname"] == "t20" and "target" not in active[0].fields;
}

test "a Q3 level's notsingle entities are left out of the ladder" {
    fields = {"classname": "item_flight", "notsingle": "1"};
    assert active_entities("q3", [MapEntity(fields=fields)]) == [];
}

test "the crosshair goes from white through yellow to red" {
    assert crosshair_tint(100, 0) == [255, 255, 255, 255];
    assert crosshair_tint(60, 0)[1:3] == [255, 0];
    assert crosshair_tint(20, 0)[1:3] == [0, 0];
}
