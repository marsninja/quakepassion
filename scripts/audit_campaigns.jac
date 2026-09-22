"""Inventory authored entities in installed maps without loading textures or models."""
import os;
import from engine.assets.library { AssetLibrary }
import from engine.formats.bsp { i32_at, require_range, parse_entities }
with entry {
    for game in ["q1", "q2", "q3"] {
        folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
        library = AssetLibrary(game=game);
        library.open(os.environ.get("HOME", "") + "/quake-assets/" + folder);
        try {
            names: set[str] = set();
            for pak in library.paks {
                for name in pak.names() {
                    names.add(name);
                }
            }
            for archive in library.pk3.archives {
                for name in archive.namelist() {
                    names.add(name);
                }
            }
            totals: dict[str, int] = {};
            maps = 0;
            for name in sorted(names) {
                if not name.startswith("maps/") or not name.endswith(".bsp") {
                    continue;
                }
                data = library.read(name);
                base = 4 if game == "q1" else 8;
                offset = i32_at(data, base);
                size = i32_at(data, base + 4);
                require_range(data, offset, size);
                entities = parse_entities(
                    data[offset:offset + size].decode("utf-8", errors="replace")
                );
                classes = [entity.fields.get("classname", "") for entity in entities];
                if not any(kind.startswith("info_player") for kind in classes) {
                    continue;
                }
                maps += 1;
                for kind in classes {
                    totals[kind] = totals.get(kind, 0) + 1;
                }
                hazards = classes.count("trigger_hurt");
                if hazards { print("HAZARDS",game,name,hazards); }
                trains = classes.count("func_train");
                if trains {
                    print("TRAINS", game, name, trains);
                }
            }
            print("MAPS", game, maps);
            for kind in sorted(totals) {
                print("ENTITY", game, kind, totals[kind]);
            }
        } finally {
            library.close();
        }
    }
}
