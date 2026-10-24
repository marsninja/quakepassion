import os;
import from games.passion.generate { Forge }

"""Where the three games are kept (QP_ASSETS, else ~/quake-assets), or ""
when Quake's is not there, or when slow tests are not asked for: making a
level under `jac test` takes about half an hour (QP_SLOW_TESTS=1 runs it;
`QP_LEVELS=trace-e1m1 .jac/qp-forge` makes the same level natively in
under a minute)."""
def passion_assets -> str {
    if not os.getenv("QP_SLOW_TESTS", "") {
        return "";
    }
    assets = os.getenv("QP_ASSETS") or (os.getenv("HOME", "") + "/quake-assets");
    return assets if os.path.exists(assets + "/id1") else "";
}

test "a level made from e1m1's essence proves, its floors rise again and its slime stays slime" {
    assets = passion_assets();
    if not assets {
        return;
    }
    forge = Forge(name="trace-e1m1", directory=assets);
    forge.complete();
    assert not forge.failure;
    record = forge.survey;
    assert record is not None;
    # Its own graph, read off the made level, proves: the way out is
    # reached from the start whatever is done on the way.
    assert record.proven;
    # The graph it was proven by is kept, for its breadcrumb trail.
    assert record.atlas is not None;
    casting = record.casting;
    assert casting is not None and casting.exit_low;
    # A floor that lowers comes back up a few seconds later, touched rather
    # than fired once (a one-way floor would strand a player).
    lowering = [item for item in casting.items if item.fields.get("classname", "") == "func_door" and item.fields.get("angle", "") == "-2"];
    for item in lowering {
        assert item.fields.get("wait", "") == "3" and "targetname" not in item.fields;
    }
    # e1m1 has slime, which stays slime (contents 16), never lava.
    contents: list[int] = [];
    for item in record.items {
        for brush in item.brushes {
            for side in brush {
                if side.contents in [8, 16] and side.contents not in contents {
                    contents.append(side.contents);
                }
            }
        }
    }
    assert 16 in contents;
}
