import os;
import tempfile;
import from engine.core.menu { loose_maps }
import from engine.world.level { asset }

test "map files lying loose in a folder's maps/ are listed as archives name them" {
    with tempfile.TemporaryDirectory(prefix="qp-loose-") as folder {
        os.makedirs(folder + "/maps/nested.bsp");
        for name in ["dm2.bsp", "dm1.bsp", "DM3.BSP", "dm1.lit", "notes.txt"] {
            with open(folder + "/maps/" + name, "wb") as file {
                file.write(b"x");
            }
        }
        assert loose_maps(folder) == ["maps/DM3.BSP", "maps/dm1.bsp", "maps/dm2.bsp"] , str(loose_maps(folder));
    }
    assert loose_maps("/no/such/folder/anywhere") == [];
}

test "a Quake level's files are read from the paks, else loose in the search path" {
    with tempfile.TemporaryDirectory(prefix="qp-asset-") as base {
        with tempfile.TemporaryDirectory(prefix="qp-asset-") as over {
            os.makedirs(base + "/maps");
            os.makedirs(over + "/maps");
            with open(base + "/maps/dm1.bsp", "wb") as file {
                file.write(b"base");
            }
            with open(base + "/maps/shared.bsp", "wb") as file {
                file.write(b"base");
            }
            with open(over + "/maps/shared.bsp", "wb") as file {
                file.write(b"over");
            }
            path = base + ";" + over;
            assert asset([], "maps/dm1.bsp", path) == b"base";
            # The later folder of the path is searched first.
            assert asset([], "maps/shared.bsp", path) == b"over";
            missing = False;
            try {
                asset([], "maps/../maps/dm1.bsp", path);
            } except ValueError {
                missing = True;
            }
            assert missing;
            missing = False;
            try {
                asset([], "maps/dm1.bsp");
            } except ValueError {
                missing = True;
            }
            assert missing;
        }
    }
}
