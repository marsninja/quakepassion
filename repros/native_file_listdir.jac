"""Native file and directory APIs must share a compatible libc errno declaration."""
import os;
import from pathlib { Path }

with entry {
    data = Path("jac.toml").read_bytes();
    names = os.listdir(".");
    assert len(data) > 0 and "jac.toml" in names;
    print("NATIVE FILE LISTDIR PASS");
}
