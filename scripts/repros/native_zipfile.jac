"""Native PK3 loading blocker: compile with jac build --native.

Compilation fails before opening the archive, so no game assets are needed
to reproduce E5090. Run from the repository root to use its local compiler.
"""
import zipfile;

with entry {
    with zipfile.ZipFile("pak0.pk3") as archive {
        data = archive.read("maps/q3dm1.bsp");
        print(len(data));
    }
}
