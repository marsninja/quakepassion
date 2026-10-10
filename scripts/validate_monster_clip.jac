"""Q2 clip brushes on the original maps: inside a monster clip brush a
monster's box is in solid and the player's is not, and inside a player clip
brush the other way round (MASK_MONSTERSOLID against MASK_PLAYERSOLID). The
two views share every other hull, so a point where they differ lies in a
clip brush that names only one of them.

    jac build scripts/validate_monster_clip.jac --native -o .jac/validate_monster_clip
    QP_MAPS=base1,train DYLD_LIBRARY_PATH=vendor .jac/validate_monster_clip
"""
import os;
import from engine.world.level { load_level }
import from engine.world.world { World }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

"""How many of `hulls` have a point, on a 3 by 3 by 3 grid through their
bounds, where `stopped` starts in solid and `passing` does not."""
def clip_shown(stopped: CollisionMap, passing: CollisionMap, hulls: list[int]) -> int {
    shown = 0;
    for hull in hulls {
        box = stopped.bounds[hull];
        found = False;
        for step in range(27) {
            spot = Vec3(
                x=box.mins.x + (box.maxs.x - box.mins.x) * float(1 + step % 3) / 4.0,
                y=box.mins.y + (box.maxs.y - box.mins.y) * float(1 + (step // 3) % 3) / 4.0,
                z=box.mins.z + (box.maxs.z - box.mins.z) * float(1 + step // 9) / 4.0
            );
            if stopped.trace(spot, spot).start_solid and not passing.trace(spot, spot).start_solid {
                found = True;
                break;
            }
        }
        if found {
            shown += 1;
        }
    }
    return shown;
}

with entry {
    directory = os.getenv("HOME", "") + "/quake-assets/baseq2";
    total = 0;
    shown = 0;
    barred = 0;
    for name in os.getenv("QP_MAPS", "base1,train,jail4,city1").split(",") {
        level = load_level(World(), directory, name, "q2");
        player = level.collision;
        monster = player.for_body(player.eye_height, 0.0, None, None, "monster");
        # The world's own clip brushes; those of plats, doors and walls
        # that come and go ride with their movers and are only counted.
        for_monsters = [hull for hull in sorted(list(player.monster_clips)) if player.models[hull] == 0];
        for_players = [hull for hull in sorted(list(player.player_clips)) if player.models[hull] == 0];
        moving = len(player.monster_clips) + len(player.player_clips) - len(for_monsters) - len(for_players);
        stops_monsters = clip_shown(monster, player, for_monsters);
        stops_players = clip_shown(player, monster, for_players);
        print(
            "MONSTER CLIP", name,
            "| monster clip brushes", len(for_monsters), "stopping only monsters", stops_monsters,
            "| player clip brushes", len(for_players), "stopping only players", stops_players,
            "| on movers", moving
        );
        total += len(for_monsters);
        shown += stops_monsters;
        barred += stops_players;
    }
    # A clip brush sunk in other solid shows nothing either way; over the
    # maps there are plenty of each kind standing in the open.
    assert total > 0 and shown > 0 and barred > 0;
    print("MONSTER CLIP PASS");
}
