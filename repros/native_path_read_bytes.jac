"""Path.read_bytes works in Jac's host runtime but is missing from native pathlib."""
import from pathlib { Path }

with entry {
    data = Path("jac.toml").read_bytes();
    assert data.startswith(b"[project]");
    print("PATH READ BYTES PASS", len(data));
}
