"""Which monsters gib, and into what, from the original die functions. Q1
thresholds come from `self.health < N` (stored as N - 1 so every game tests
health <= threshold); Q2 from each monster's gib_health; Q3 from GIB_HEALTH."""
import from engine.world.gibs { GibRule, GibsInto }
import from engine.world.world { World, Entity }
import from engine.world.models { ModelResource, HasModelResource }
import from engine.assets.library { AssetLibrary }

def q1_gibs(threshold: int, head: str, pieces: list[str], sound: str = "sound/player/udeath.wav") -> GibRule {
    return GibRule(
        threshold=threshold,
        head="progs/" + head + ".mdl",
        pieces=["progs/" + piece + ".mdl" for piece in pieces],
        sound=sound,
        style="q1"
    );
}

def q2_gibs(threshold: int, head: str, bones: int, meat: int, extra: list[str] = []) -> GibRule {
    pieces: list[str] = [];
    for i in range(bones) {
        pieces.append("models/objects/gibs/bone/tris.md2");
    }
    for i in range(meat) {
        pieces.append("models/objects/gibs/sm_meat/tris.md2");
    }
    for piece in extra {
        pieces.append("models/objects/gibs/" + piece + "/tris.md2");
    }
    return GibRule(
        threshold=threshold,
        head="models/objects/gibs/" + head + "/tris.md2",
        pieces=pieces,
        sound="sound/misc/udeath.wav",
        style="q2"
    );
}

def gib_rule(game: str, kind: str) -> GibRule | None {
    if game == "q1" {
        if kind == "monster_army" {
            return q1_gibs(-36, "h_guard", ["gib1", "gib2", "gib3"]);
        }
        if kind == "monster_dog" {
            return q1_gibs(-36, "h_dog", ["gib3", "gib3", "gib3"]);
        }
        if kind == "monster_demon1" {
            return q1_gibs(-81, "h_demon", ["gib1", "gib1", "gib1"]);
        }
        if kind == "monster_enforcer" {
            return q1_gibs(-36, "h_mega", ["gib1", "gib2", "gib3"]);
        }
        if kind == "monster_hell_knight" {
            return q1_gibs(-41, "h_hellkn", ["gib1", "gib2", "gib3"]);
        }
        if kind == "monster_knight" {
            return q1_gibs(-41, "h_knight", ["gib1", "gib2", "gib3"]);
        }
        if kind in ["monster_ogre", "monster_ogre_marksman"] {
            return q1_gibs(-81, "h_ogre", ["gib3", "gib2", "gib1"]);
        }
        if kind == "monster_shalrath" {
            return q1_gibs(-91, "h_shal", ["gib1", "gib2", "gib3"]);
        }
        if kind == "monster_shambler" {
            return q1_gibs(-61, "h_shams", ["gib1", "gib2", "gib3"]);
        }
        if kind == "monster_wizard" {
            return q1_gibs(-41, "h_wizard", ["gib2", "gib2", "gib2"]);
        }
        # Zombies only die by being blown apart.
        if kind == "monster_zombie" {
            return q1_gibs(0, "h_zombie", ["gib1", "gib2", "gib3"], "sound/zombie/z_gib.wav");
        }
        return None;
    }
    if game == "q2" {
        if kind in ["monster_soldier", "monster_soldier_light", "monster_soldier_ss"] {
            return q2_gibs(-30, "head2", 0, 3, ["chest"]);
        }
        if kind == "monster_infantry" {
            return q2_gibs(-40, "head2", 1, 4);
        }
        if kind in ["monster_gunner", "monster_chick"] {
            return q2_gibs(-70, "head2", 2, 4);
        }
        if kind == "monster_berserk" {
            return q2_gibs(-60, "head2", 2, 4);
        }
        if kind == "monster_gladiator" {
            return q2_gibs(-175, "head2", 2, 4);
        }
        if kind == "monster_medic" {
            return q2_gibs(-130, "head2", 2, 4);
        }
        if kind == "monster_brain" {
            return q2_gibs(-150, "head2", 2, 4);
        }
        if kind == "monster_mutant" {
            return q2_gibs(-120, "head2", 2, 4);
        }
        if kind == "monster_parasite" {
            return q2_gibs(-50, "head2", 2, 4);
        }
        if kind == "misc_insane" {
            return q2_gibs(-50, "head2", 2, 4);
        }
        if kind in ["monster_tank", "monster_tank_commander"] {
            return q2_gibs(-200, "gear", 0, 1, ["sm_metal", "sm_metal", "sm_metal", "sm_metal", "chest"]);
        }
        # m_supertank.c BossExplode (also boss2 and Jorg): once the death
        # animation ends the wreck blows apart; damage never gibs them.
        if kind in ["monster_supertank", "monster_jorg"] {
            bits = q2_gibs(-100000, "gear", 0, 2, ["sm_metal", "sm_metal", "chest"]);
            bits.sound = "sound/weapons/rocklx1a.wav";
            return bits;
        }
        if kind == "monster_boss2" {
            bits = q2_gibs(-100000, "head2", 2, 2);
            bits.sound = "sound/weapons/rocklx1a.wav";
            return bits;
        }
        if kind == "monster_flipper" {
            return q2_gibs(-30, "sm_meat", 2, 2);
        }
        if kind == "monster_hover" {
            return q2_gibs(-100, "sm_meat", 2, 2);
        }
        return None;
    }
    if game == "q3" and kind == "arena_bot" {
        # cg_players.c CG_GibPlayer, thrown when health falls to GIB_HEALTH.
        return GibRule(
            threshold=-40,
            head="models/gibs/skull.md3",
            pieces=[
                "models/gibs/brain.md3",
                "models/gibs/abdomen.md3",
                "models/gibs/arm.md3",
                "models/gibs/chest.md3",
                "models/gibs/fist.md3",
                "models/gibs/foot.md3",
                "models/gibs/forearm.md3",
                "models/gibs/intestine.md3",
                "models/gibs/leg.md3",
                "models/gibs/leg.md3"
            ],
            sound="sound/player/gibsplt1.wav",
            style="q3"
        );
    }
    return None;
}

"""Link a monster to the models it breaks into, loading each once per level.
Returns False when the game data lacks any of them, leaving the monster to die
whole."""
def link_gibs(
    world: World,
    victim: Entity,
    rule: GibRule,
    library: AssetLibrary,
    source: str,
    resources: dict[str, ModelResource]
) -> bool {
    paths = [rule.head] + rule.pieces;
    try {
        for path in paths {
            key = "gib:" + source + ":" + path;
            if key not in resources {
                loaded = library.model(path);
                resource = ModelResource(name=key, model=loaded.model, skins=loaded.skins);
                resources[key] = resource;
                world +>:HasModelResource:+> resource;
            }
        }
    } except Exception {
        return False;
    }
    linked: list[str] = [];
    for index in range(len(paths)) {
        path = paths[index];
        if path in linked {
            continue;
        }
        linked.append(path);
        victim +>:GibsInto:count=paths.count(path), head=index == 0:+> resources["gib:" + source + ":" + path];
    }
    return True;
}
