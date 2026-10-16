"""Export rooms, encounters and actual navigation features for human review.

    jac build scripts/passion_design_audit.jac --native -o .jac/qp-design
    QP_SEEDS="4 25 84 100" .jac/qp-design > .jac/design.jsonl

This exposes the spatial evidence behind a review without requiring a bot
to find its way. Positions are world units; room bounds use massing cells.
"""
import os;
import json;
import from games.passion.generate { survey }
import from games.passion.arrange { estate_spaces, estate_corridors }
import from games.passion.experience { encounters, Supplies, Reward, HoldsPosition, CombatPosition }
import from games.passion.wayfinding { route_cues }

with entry {
    for word in os.getenv("QP_SEEDS", "4 25 84 100").split() {
        record = survey(int(word));
        estate = record.estate;
        casting = record.casting;
        dressing = record.dressing;
        assert estate is not None and casting is not None and dressing is not None;
        rooms: list[dict[str, any]] = [];
        for space in estate_spaces(estate) {
            if space.role in ["corridor", "window"] { continue; }
            rooms.append({
                "id": space.id, "role": space.role, "kind": space.kind,
                "order": space.order, "optional": space.optional,
                "centre": space.centre, "district": space.district,
                "box": [space.x, space.y, space.z, space.w, space.d, space.h],
                "stage": space.stage, "levels": space.levels
            });
        }
        ways: list[dict[str, any]] = [];
        for corridor in estate_corridors(estate) {
            ways.append({
                "id": corridor.link, "tail": corridor.tail, "head": corridor.head,
                "mode": corridor.mode, "needs": corridor.needs,
                "window": corridor.window, "teleport": corridor.teleport,
                "connector": corridor.connector, "column": corridor.column,
                "low": corridor.low, "high": corridor.high,
                "certified": corridor.certified, "blocks": corridor.blocks
            });
        }
        fights: list[dict[str, any]] = [];
        for encounter in encounters(casting.experience) {
            fights.append({
                "room": encounter.room, "pattern": encounter.pattern,
                "approach": encounter.approach, "foes": encounter.foes,
                "health_added": encounter.health_added,
                "health_after": encounter.health_after,
                "ammo_needed": encounter.ammo_needed,
                "ammo_ready": encounter.ammo_ready,
                "positions": [{"at": p.point, "role": p.role, "foe": p.foe}
                    for p in [encounter->:HoldsPosition:->][?:CombatPosition]],
                "rewards": [{"at": r.point, "kind": r.kind, "source": r.source, "amount": r.amount}
                    for r in [encounter->:Supplies:->][?:Reward]]
            });
        }
        print(json.dumps({
            "seed": record.seed, "theme": record.theme,
            "rooms": rooms, "ways": ways, "encounters": fights,
            "entities": [item.fields for item in casting.items],
            "cues": [{"room": cue.room, "destination": cue.destination, "link": cue.link,
                "kind": cue.kind, "point": cue.point} for cue in route_cues(casting.navigation)],
            "lights": [[lamp.x, lamp.y, lamp.z, lamp.level, lamp.color] for lamp in dressing.lamps],
            "measures": record.measures
        }));
    }
}
