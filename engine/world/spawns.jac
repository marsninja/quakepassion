"""Select authored entities for normal campaigns and local Q3 free-for-all."""
import from engine.formats.numbers { atof, atoi }
import from ..formats.bsp { MapEntity }

"""Q1/Q2 NOT_EASY (256), NOT_MEDIUM (512) and NOT_HARD (1024) spawnflags pick
the skill's entities; Nightmare (3) uses the Hard set."""
def skill_exclusion(skill: int) -> int {
    return 256 if skill <= 0 else (512 if skill == 1 else 1024);
}

def active_entities(game: str, entities: list[MapEntity], skill: int = 1) -> list[MapEntity] {
    result: list[MapEntity] = [];
    excluded = skill_exclusion(skill);
    for entity in entities {
        fields = entity.fields;
        flags = atoi(fields.get("spawnflags", "0"));
        if game in ["q1", "q2"] {
            if fields.get("classname", "") != "worldspawn" and flags & excluded != 0 {
                continue;
            }
            fields = dict(fields);
            fields["spawnflags"] = str(flags & ~(7936 if game == "q2" else 3840));
            # A trigger-spawned Q2 monster named only by its target is called
            # by that name (SP_monster_flyer's fix for jail5), or it would
            # never come.
            if game == "q2"
                and fields.get("classname", "").startswith("monster_")
                and flags & 2 != 0
                and not fields.get("targetname", "")
                and fields.get("target", "") {
                fields["targetname"] = fields.pop("target");
            }
        } elif game == "q3" and fields.get("classname", "") != "worldspawn" {
            if atoi(fields.get("notfree", "0")) != 0
                or atoi(fields.get("notsingle", "0")) != 0
                or atoi(fields.get("notq3a", "0")) != 0 {
                continue;
            }
            if "gametype" in fields and "ffa" not in fields["gametype"] {
                continue;
            }
        }
        result.append(MapEntity(fields=fields));
    }
    return result;
}
