"""Select authored entities for normal campaigns and local Q3 free-for-all."""
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
        flags = int(fields.get("spawnflags", "0"));
        if game in ["q1", "q2"] {
            if fields.get("classname", "") != "worldspawn" and flags & excluded != 0 {
                continue;
            }
            fields = dict(fields);
            fields["spawnflags"] = str(flags & ~(7936 if game == "q2" else 3840));
        } elif game == "q3" and fields.get("classname", "") != "worldspawn" {
            if int(fields.get("notfree", "0")) != 0
                or int(fields.get("notq3a", "0")) != 0 {
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
