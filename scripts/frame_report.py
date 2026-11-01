"""frame_report.py <frames.csv> [more.csv ...]: what QP_FRAME_LOG recorded. Frame
times by percentile, the slow frames and how regularly they come, and which
stage each slow frame spent its time in."""
import csv, statistics, sys

STAGES = ["visible", "portal", "world", "models", "effects", "weapon", "hud"]


def report(path):
    rows = [{k: float(v) for k, v in row.items()} for row in csv.DictReader(open(path))]
    rows = rows[60:]
    frames = sorted(r["frame"] for r in rows)
    median = statistics.median(frames)
    at = lambda q: frames[min(len(frames) - 1, int(len(frames) * q))]
    print(path)
    print(f"  {len(rows)} frames over {rows[-1]['at'] - rows[0]['at']:.0f} s, median {median:.1f} ms, p95 {at(.95):.1f}, p99 {at(.99):.1f}, p99.9 {at(.999):.1f}, worst {frames[-1]:.1f}")
    print(f"  ticks per frame: " + ", ".join(f"{t}:{sum(r['ticks'] == t for r in rows)}" for t in sorted({r["ticks"] for r in rows})))
    slow = [r for r in rows if r["frame"] > max(median * 1.5, median + 4.0)]
    minutes = (rows[-1]["at"] - rows[0]["at"]) / 60.0
    print(f"  slow frames (over {max(median * 1.5, median + 4.0):.1f} ms): {len(slow)}, {len(slow) / max(minutes, 1e-9):.0f} a minute")
    gaps = [b["at"] - a["at"] for a, b in zip(slow, slow[1:])]
    if len(gaps) > 3:
        print(f"  seconds between them: median {statistics.median(gaps):.2f}, p10 {sorted(gaps)[len(gaps) // 10]:.2f}, p90 {sorted(gaps)[len(gaps) * 9 // 10]:.2f}")
    for r in sorted(slow, key=lambda r: -r["frame"])[:12]:
        drawn = sum(r[s] for s in STAGES)
        rest = r["frame"] - drawn - r["present"] - r["before"] - r["sim"]
        top = sorted(STAGES, key=lambda s: -r[s])[0]
        print(f"    t {r['at']:7.2f}  {r['frame']:6.1f} ms  ticks {r['ticks']:.0f}  before {r['before']:6.1f}  sim {r['sim']:6.1f}  drawn {drawn:6.1f} ({top} {r[top]:.1f})  present {r['present']:6.1f}  rest {rest:6.1f}")


for name in sys.argv[1:]:
    report(name)
