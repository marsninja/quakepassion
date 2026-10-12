import os;
import tempfile;
import from editor.assets.explorer { own_files }
import from editor.formats.archive { folder_children }

test "a folder on disk is listed as its files, by their paths from it" {
    with tempfile.TemporaryDirectory(prefix="qp-own-") as home {
        os.makedirs(home + "/textures/walls");
        os.makedirs(home + "/scenes");
        os.makedirs(home + "/.hidden");
        for name in ["project.qp", "textures/crate.png", "textures/walls/brick.tga", "scenes/yard.map", ".hidden/secret.txt", ".keep"] {
            with open(home + "/" + name, "w") as file {
                file.write("x");
            }
        }
        found = own_files(home);
        assert found == ["project.qp", "scenes/yard.map", "textures/crate.png", "textures/walls/brick.tga"] , str(found);
        # As the explorer lists a game's files: folders, then the files of each.
        top = folder_children(found, "");
        assert top[0] == ["scenes", "textures"] and top[1] == ["project.qp"] , str(top);
        assert folder_children(found, "textures") == (["walls"], ["crate.png"]);
    }
    assert own_files("") == [] and own_files("/no/such/folder/anywhere") == [];
}
