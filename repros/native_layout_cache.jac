"""Regression: a cached native reader must invalidate after an imported layout edit.
Run with: jac run repros/native_layout_cache.jac
"""
import os;
import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

def build_and_run(folder: Path, name: str) -> str {
    binary = folder / name;
    subprocess.run(
        ["jac", "build", str(folder / "main.jac"), "--native", "-o", str(binary)],
        env=dict(os.environ),
        check=True,
        timeout=120
    );
    result = subprocess.run(
        [str(binary)], capture_output=True, text=True, check=True, timeout=10
    );
    return result.stdout.strip();
}

with entry {
    with TemporaryDirectory(prefix="qp-native-layout-") as directory {
        folder = Path(directory);
        record = folder / "record.jac";
        record.write_text("obj Record { has value: int = 42; }\n");
        (folder / "reader.jac").write_text(
            "import from .record { Record }\n"
                + "def read(record: Record) -> int { return record.value; }\n"
        );
        (folder / "main.jac").write_text(
            "import from .record { Record }\n"
                + "import from .reader { read }\n"
                + "with entry { print(read(Record(value=42))); }\n"
        );
        before = build_and_run(folder, "before");
        assert before == "42";
        record.write_text("obj Record { has padding: int = 99, value: int = 42; }\n");
        after = build_and_run(folder, "after");
        print("Before layout edit:", before, "After warm rebuild:", after);
        assert after == "42" , "Native dependency cache reused an obsolete object layout";
    }
}
