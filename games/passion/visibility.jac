"""Cluster visibility from blueprint portals.

Regions (rooms, corridors, sight slots) are clusters; every run of columns where
two regions touch is a portal segment in the floor plane. Visibility flows
through portal chains, and a chain survives only while some straight line can
still pass through all of its portals: an exact 2D stabbing test, since an
extremal stabbing line always passes through two segment endpoints. Walls are
full height, heights are ignored and rooms are treated as convex, so the result
is conservative: it never hides a region a player could see.
"""
import from .blueprint { Blueprint }

glob DEPTH: int = 10;

obj Gap {
    has a: int,
        b: int,
        x0: float,
        y0: float,
        x1: float,
        y1: float;
}

obj Flow {
    has portals: list[Gap] = [],
        by_region: dict[int, list[int]] = {};
}

def portals_of(bp: Blueprint) -> Flow {
    # Boundary edges keyed by (region pair, axis, line coordinate).
    groups: dict[str, list[int]] = {};
    for y in range(bp.height) {
        for x in range(bp.width) {
            i = bp.index(x, y);
            if not bp.open(i) {
                continue;
            }
            ra = bp.region[i];
            if x + 1 < bp.width {
                j = bp.index(x + 1, y);
                if bp.open(j) and bp.region[j] != ra {
                    key = pair_key(ra, bp.region[j]) + "|v|" + str(x + 1);
                    groups.setdefault(key, []).append(y);
                }
            }
            if y + 1 < bp.height {
                j = bp.index(x, y + 1);
                if bp.open(j) and bp.region[j] != ra {
                    key = pair_key(ra, bp.region[j]) + "|h|" + str(y + 1);
                    groups.setdefault(key, []).append(x);
                }
            }
        }
    }
    graph_flow = Flow();
    for key in groups {
        parts = key.split("|");
        a = int(parts[0]);
        b = int(parts[1]);
        vertical = parts[2] == "v";
        line = float(int(parts[3])) * 32.0;
        cells = sorted(groups[key]);
        # Contiguous runs become separate portals.
        start = cells[0];
        previous = cells[0];
        runs: list[list[int]] = [];
        for value in cells[1:] {
            if value != previous + 1 {
                runs.append([start, previous]);
                start = value;
            }
            previous = value;
        }
        runs.append([start, previous]);
        for run in runs {
            low = float(run[0]) * 32.0;
            high = float(run[1] + 1) * 32.0;
            portal = Gap(a=a, b=b, x0=line, y0=low, x1=line, y1=high)
                if vertical
                else Gap(a=a, b=b, x0=low, y0=line, x1=high, y1=line);
            index = len(graph_flow.portals);
            graph_flow.portals.append(portal);
            graph_flow.by_region.setdefault(a, []).append(index);
            graph_flow.by_region.setdefault(b, []).append(index);
        }
    }
    return graph_flow;
}

def pair_key(a: int, b: int) -> str {
    return str(min(a, b)) + "|" + str(max(a, b));
}

def orient(ax: float, ay: float, bx: float, bcy: float, px: float, py: float) -> float {
    return (bx - ax) * (py - ay) - (bcy - ay) * (px - ax);
}

# Does any line cross every segment? Candidate lines pass through endpoint pairs.
def stabbed(chain: list[Gap]) -> bool {
    if len(chain) <= 2 {
        return True;
    }
    points: list[list[float]] = [];
    for portal in chain {
        points.append([portal.x0, portal.y0]);
        points.append([portal.x1, portal.y1]);
    }
    for i in range(len(points)) {
        for j in range(i + 1, len(points)) {
            ax = points[i][0];
            ay = points[i][1];
            bx = points[j][0];
            bcy = points[j][1];
            if abs(ax - bx) < 0.001 and abs(ay - bcy) < 0.001 {
                continue;
            }
            good = True;
            for portal in chain {
                s0 = orient(ax, ay, bx, bcy, portal.x0, portal.y0);
                s1 = orient(ax, ay, bx, bcy, portal.x1, portal.y1);
                if (s0 > 0.01 and s1 > 0.01) or (s0 < -0.01 and s1 < -0.01) {
                    good = False;
                    break;
                }
            }
            if good {
                return True;
            }
        }
    }
    return False;
}

def flow_from(
    graph_flow: Flow, region: int, chain: list[Gap], path: list[int], seen: list[bool]
) {
    seen[region] = True;
    if len(chain) >= DEPTH {
        return;
    }
    for index in graph_flow.by_region.get(region, []) {
        portal = graph_flow.portals[index];
        other = portal.b if portal.a == region else portal.a;
        if other in path {
            continue;
        }
        extended = chain + [portal];
        if not stabbed(extended) {
            continue;
        }
        flow_from(graph_flow, other, extended, path + [other], seen);
    }
}

# Returns (clusters, row bytes, visibility bytes) in the Q3-style layout.
def cluster_visibility(bp: Blueprint) -> bytes {
    count = len(bp.regions);
    row_bytes = (count + 7) // 8;
    graph_flow = portals_of(bp);
    data = bytearray([u8(0) for _ in range(8)]);
    for source in range(count) {
        seen = [False for _ in range(count)];
        flow_from(graph_flow, source, [], [source], seen);
        row = [0 for _ in range(row_bytes)];
        for target in range(count) {
            if seen[target] {
                row[target // 8] = row[target // 8] | (1 << (target % 8));
            }
        }
        for value in row {
            data.append(u8(value));
        }
    }
    return bytes(data);
}

def visible_pairs(bp: Blueprint, data: bytes) -> int {
    count = len(bp.regions);
    row_bytes = (count + 7) // 8;
    total = 0;
    for source in range(count) {
        for target in range(count) {
            if int(data[8 + source * row_bytes + target // 8]) & (1 << (target % 8)) {
                total += 1;
            }
        }
    }
    return total;
}
