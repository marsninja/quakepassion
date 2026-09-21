"""Native os.replace must atomically replace the destination, not silently do nothing."""
import os;

with entry {
    source = ".jac/native-replace-source.txt";
    target = ".jac/native-replace-target.txt";
    with open(source, "w") as stream {
        stream.write("new");
    }
    with open(target, "w") as stream {
        stream.write("old");
    }
    os.replace(source, target);
    assert not os.path.exists(source);
    with open(target, "r") as stream {
        assert stream.read() == "new";
    }
    os.remove(target);
    print("NATIVE REPLACE PASS");
}
