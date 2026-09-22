"""Python target succeeds; native lowering currently rejects os.path.expanduser."""
import os;
with entry {
    print(os.path.expanduser("~/.cache/quakepassion/lighting"));
}
