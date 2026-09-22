"""Select authored entities for normal campaigns and local Q3 free-for-all."""
import from ..formats.bsp { MapEntity }

def active_entities(game: str, entities: list[MapEntity]) -> list[MapEntity] {
    result: list[MapEntity] = [];
    for entity in entities {
        fields = entity.fields;
        flags = int(fields.get("spawnflags", "0"));
        if game in ["q1", "q2"] {
            if fields.get("classname", "") != "worldspawn" and flags & 512 != 0 {
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
