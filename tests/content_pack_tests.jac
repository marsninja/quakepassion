import os;
import tempfile;
import from engine.assets.content { shelf, stands_alone, pack_path, pack_start_map, playing }
import from engine.core.menu { loose_maps }
import from engine.world.level { asset }

test "the free games stand alone on their own folders; mission packs do not" {
    libre = shelf().find("librequake");
    arena = shelf().find("openarena");
    assert libre is not None and arena is not None;
    assert libre.game == "q1" and libre.folder == "librequake/id1";
    assert arena.game == "q3" and arena.folder == "openarena/baseoa";
    assert stands_alone(libre) and stands_alone(arena);
    # Their search paths hold their own folder alone, not Quake's or Quake III's.
    assert pack_path(libre).endswith("/librequake/id1") and ";" not in pack_path(libre);
    assert pack_path(arena).endswith("/openarena/baseoa") and ";" not in pack_path(arena);
    hipnotic = shelf().find("hipnotic");
    team = shelf().find("teamarena");
    assert hipnotic is not None and team is not None;
    assert not stands_alone(hipnotic) and not stands_alone(team);
    # Listed beside the game they play by, after it.
    q1 = [pack.id for pack in shelf().packs("q1")];
    q3 = [pack.id for pack in shelf().packs("q3")];
    assert q1[:2] == ["q1", "librequake"] and q3 == ["q3", "openarena", "teamarena"] , str(q1) + str(q3);
}

test "LibreQuake opens on its start map, OpenArena on its ladder's first arena" {
    assert pack_start_map("librequake") == "start";
    assert pack_start_map("openarena") == "oa_rpg3dm2";
}

"""The id of the pack a game is playing; "" when there is none."""
def playing_id(game: str) -> str {
    found = playing(game);
    return found.id if found is not None else "";
}

test "a game whose own data is missing plays the free game made for its engine" {
    kept_assets = os.environ.get("QP_ASSETS", "");
    kept_game = os.environ.get("QP_GAME", "");
    with tempfile.TemporaryDirectory(prefix="qp-packs-") as assets {
        # QP_ASSETS names Quake III's own folder; its parent is the assets root.
        os.environ["QP_ASSETS"] = assets + "/baseq3";
        os.environ["QP_GAME"] = "q3";
        try {
            # Neither is there: the game itself, as before.
            assert playing_id("q3") == "q3";
            # Team Arena alone cannot play without Quake III.
            os.makedirs(assets + "/quake3/missionpack");
            assert playing_id("q3") == "q3";
            os.makedirs(assets + "/openarena/baseoa");
            assert playing_id("q3") == "openarena";
            # Quake III's own data comes first once it is there.
            os.makedirs(assets + "/baseq3");
            assert playing_id("q3") == "q3";
        } finally {
            os.environ["QP_ASSETS"] = kept_assets;
            os.environ["QP_GAME"] = kept_game;
            if not kept_assets {
                del os.environ["QP_ASSETS"];
            }
            if not kept_game {
                del os.environ["QP_GAME"];
            }
        }
    }
}

test "map files lying loose in a folder's maps/ are listed as archives name them" {
    with tempfile.TemporaryDirectory(prefix="qp-loose-") as folder {
        os.makedirs(folder + "/maps/nested.bsp");
        for name in ["lqdm2.bsp", "lqdm1.bsp", "LQDM3.BSP", "lqdm1.lit", "notes.txt"] {
            with open(folder + "/maps/" + name, "wb") as file {
                file.write(b"x");
            }
        }
        assert loose_maps(folder) == ["maps/LQDM3.BSP", "maps/lqdm1.bsp", "maps/lqdm2.bsp"] , str(loose_maps(folder));
    }
    assert loose_maps("/no/such/folder/anywhere") == [];
}

test "a Quake level's files are read from the paks, else loose in the search path" {
    with tempfile.TemporaryDirectory(prefix="qp-asset-") as base {
        with tempfile.TemporaryDirectory(prefix="qp-asset-") as over {
            os.makedirs(base + "/maps");
            os.makedirs(over + "/maps");
            with open(base + "/maps/lqdm1.bsp", "wb") as file {
                file.write(b"base");
            }
            with open(base + "/maps/shared.bsp", "wb") as file {
                file.write(b"base");
            }
            with open(over + "/maps/shared.bsp", "wb") as file {
                file.write(b"over");
            }
            path = base + ";" + over;
            assert asset([], "maps/lqdm1.bsp", path) == b"base";
            # The later folder of the path is searched first.
            assert asset([], "maps/shared.bsp", path) == b"over";
            missing = False;
            try {
                asset([], "maps/../maps/lqdm1.bsp", path);
            } except ValueError {
                missing = True;
            }
            assert missing;
            missing = False;
            try {
                asset([], "maps/lqdm1.bsp");
            } except ValueError {
                missing = True;
            }
            assert missing;
        }
    }
}
