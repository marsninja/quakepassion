"""Campaign enemy definitions; behavioral special cases remain explicit work."""
import from engine.world.opponent_rule { OpponentRule }

def enemy_rule(game: str, kind: str) -> OpponentRule | None {
    if game == "q1" {
        if kind == "monster_boss" {
            return OpponentRule(model="progs/boss.mdl", script="chthon", health=3, speed=0.0);
        }
        if kind == "monster_army" {
            return OpponentRule(model="progs/soldier.mdl", health=30);
        }
        if kind == "monster_dog" {
            return OpponentRule(
                model="progs/dog.mdl",
                health=25,
                speed=180.0,
                melee=12,
                attack_range=100.0,
                melee_range=100.0,
                stop_range=48.0
            );
        }
        if kind == "monster_knight" {
            return OpponentRule(
                model="progs/knight.mdl",
                health=75,
                speed=160.0,
                melee=9,
                attack_range=64.0,
                stop_range=40.0
            );
        }
        if kind == "monster_enforcer" {
            return OpponentRule(
                model="progs/enforcer.mdl",
                health=80,
                damage=15,
                missile_speed=600.0,
                missile_effect="q1_laser"
            );
        }
        if kind == "monster_ogre" {
            return OpponentRule(
                model="progs/ogre.mdl",
                health=200,
                speed=120.0,
                damage=0,
                melee=6,
                missile_speed=600.0,
                missile_effect="q1_grenade",
                gravity=True,
                splash=120,
                radius=160.0,
                interval=1.0
            );
        }
    } elif game == "q2" {
        if kind == "monster_infantry" {
            return OpponentRule(model="models/monsters/infantry/tris.md2", health=100);
        }
        if kind == "monster_soldier_light" {
            return OpponentRule(
                model="models/monsters/soldier/tris.md2",
                health=20,
                damage=5,
                missile_speed=600.0,
                missile_effect="q2_bolt"
            );
        }
        if kind == "monster_soldier" {
            return OpponentRule(
                model="models/monsters/soldier/tris.md2", health=30, skin=2
            );
        }
        if kind == "monster_soldier_ss" {
            return OpponentRule(
                model="models/monsters/soldier/tris.md2", health=40, skin=4
            );
        }
    }
    return None;
}
