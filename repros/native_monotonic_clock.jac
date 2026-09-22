"""All monotonic clocks must advance while the process sleeps."""
import time;
with entry {
    mono = time.monotonic();
    perf = time.perf_counter();
    mono_ns = time.monotonic_ns();
    perf_ns = time.perf_counter_ns();
    time.sleep(0.05);
    assert time.monotonic() - mono >= 0.02;
    assert time.perf_counter() - perf >= 0.02;
    assert time.monotonic_ns() - mono_ns >= 20000000;
    assert time.perf_counter_ns() - perf_ns >= 20000000;
    print("MONOTONIC PASS");
}
