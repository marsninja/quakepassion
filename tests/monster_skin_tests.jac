import from games.enemies { enemy_rule }
import from engine.world.world { Player }
import from engine.world.combat { Opponent, Bloodied, damage_opponent, raise_patient, show_wounds }
import from engine.world.models { ModelResource, UsesModel, attach_model }
import from engine.formats.animated { AnimatedModel }
import from engine.math.vec3 { Vec3 }

test "a Q2 monster below half health shows its bloodied skin until raised" {
    rule = enemy_rule("q2", "monster_infantry", 0);
    assert rule is not None;
    enemy = Opponent(rule=rule, kind="monster_infantry", game="q2", health=100, max_health=100);
    healthy = ModelResource(name="q2:infantry:0", model=AnimatedModel(), skins=[]);
    bloodied = ModelResource(name="q2:infantry:1", model=AnimatedModel(), skins=[]);
    enemy.visual = attach_model(enemy, healthy);
    enemy +>:Bloodied:+> bloodied;
    player = Player(pos=Vec3(x=200.0));
    damage_opponent(enemy, 30, attacker=player);
    assert [enemy.visual->:UsesModel:->][?:ModelResource] == [healthy];
    damage_opponent(enemy, 30, attacker=player);
    assert enemy.wounded;
    assert [enemy.visual->:UsesModel:->][?:ModelResource] == [bloodied];
    damage_opponent(enemy, 100, attacker=player);
    assert enemy.health <= 0;
    raise_patient(enemy, Opponent(rule=rule, health=300), None);
    assert not enemy.wounded;
    assert [enemy.visual->:UsesModel:->][?:ModelResource] == [healthy];
    # A monster without a second skin keeps the one it has.
    plain = Opponent(rule=rule, health=10, max_health=100);
    plain.visual = attach_model(plain, healthy);
    show_wounds(plain, True);
    assert not plain.wounded;
}
