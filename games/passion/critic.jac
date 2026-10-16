"""The critic: how near a candidate expedition comes to the original games'
levels, by the yardstick's measures taken quickly from its massing, its
lamps and its cast, against the corpus (`corpus.jac`).

Each measure is scored by how many of the corpus's spreads (its quartiles'
span) it lies from the corpus's median, squared and capped, and weighted;
the score is the negative of their sum, so the nearer a candidate is to how
id built its levels, the higher it scores."""
import math;
import from .massing { Massing, CELL, LIFT }
import from .corpus { CORPUS_SP }
import from .dress { Lamp3 }

# The measures the critic weighs, and how much each counts.
glob CRITIC_WEIGHTS: dict[str, float] = {
         "size_x": 0.5,
         "size_y": 0.5,
         "size_z": 0.6,
         "floor_area": 0.8,
         "levels": 1.0,
         "stacked": 1.4,
         "vrange": 0.8,
         "headroom_med": 1.2,
         "headroom_p90": 0.6,
         "sight_med": 1.0,
         "sight_p90": 0.8,
         "near_med": 0.8,
         "lights_per": 0.8,
         "light_spacing": 0.8,
         "monsters_per": 0.6,
         "items_per": 0.4
     };

def:priv critic_percentile(values: list[float], share: float) -> float {
    if len(values) == 0 {
        return 0.0;
    }
    ordered = sorted(values);
    at = int(round(share * float(len(ordered) - 1)));
    return ordered[max(0, min(len(ordered) - 1, at))];
}

"""How far a ray at eye height goes through the massing's air before it
meets solid, in world units (up to `limit`), stepping a quarter cell."""
def massing_reach(mass: Massing, x: float, y: float, z: float, dx: float, dy: float, limit: float) -> float {
    travelled = 0.0;
    step = CELL * 0.25;
    cz = int(math.floor(z / LIFT));
    while travelled < limit {
        travelled += step;
        cx = int(math.floor((x + dx * travelled) / CELL));
        cy = int(math.floor((y + dy * travelled) / CELL));
        if not mass.air(cx, cy, cz) {
            return travelled;
        }
    }
    return limit;
}

"""The yardstick's measures of a candidate from its massing: floor where a
body stands (air on solid with room above), its extent and levels, floor over
floor, headroom, sightlines at eye height; lamps and cast for the floor."""
def critic_measures(mass: Massing, lamps: list[Lamp3], monsters: int, items: int) -> dict[str, float] {
    found: dict[str, float] = {};
    xs: list[float] = [];
    ys: list[float] = [];
    zs: list[float] = [];
    heads: list[float] = [];
    columns: dict[int, int] = {};
    cells: list[list[int]] = [];
    for z in range(1, mass.nz) {
        for y in range(mass.ny) {
            for x in range(mass.nx) {
                if mass.owner[(z * mass.ny + y) * mass.nx + x] == 0 or mass.owner[((z - 1) * mass.ny + y) * mass.nx + x] != 0 {
                    continue;
                }
                room = mass.headroom(x, y, z);
                if room < 4 {
                    continue;
                }
                cells.append([x, y, z]);
                xs.append((float(x) + 0.5) * CELL);
                ys.append((float(y) + 0.5) * CELL);
                zs.append(float(z) * LIFT);
                heads.append(float(room) * LIFT);
                key = y * mass.nx + x;
                columns[key] = columns.get(key, 0) + 1;
            }
        }
    }
    count = len(cells);
    if count == 0 {
        return found;
    }
    found["size_x"] = critic_percentile(xs, 0.98) - critic_percentile(xs, 0.02);
    found["size_y"] = critic_percentile(ys, 0.98) - critic_percentile(ys, 0.02);
    found["size_z"] = critic_percentile(zs, 0.98) - critic_percentile(zs, 0.02);
    floor_area = float(count) * CELL * CELL;
    found["floor_area"] = floor_area;
    unit = floor_area / 65536.0;
    bands: dict[int, int] = {};
    for z in zs {
        band = int(math.floor(z / 64.0));
        bands[band] = bands.get(band, 0) + 1;
    }
    found["levels"] = float(len([band for band in bands.values() if band * 20 >= count]));
    found["vrange"] = critic_percentile(zs, 0.9) - critic_percentile(zs, 0.1);
    stacked = 0;
    for cell in cells {
        if columns[cell[1] * mass.nx + cell[0]] > 1 {
            stacked += 1;
        }
    }
    found["stacked"] = float(stacked) / float(count);
    found["headroom_med"] = critic_percentile(heads, 0.5);
    found["headroom_p90"] = critic_percentile(heads, 0.9);
    sights: list[float] = [];
    nearest: list[float] = [];
    stride = max(1, count // 900);
    for index in range(0, count, stride) {
        cell = cells[index];
        x = (float(cell[0]) + 0.5) * CELL;
        y = (float(cell[1]) + 0.5) * CELL;
        z = float(cell[2]) * LIFT + 46.0;
        closest = 4096.0;
        for turn in range(8) {
            angle = float(turn) * math.pi / 4.0;
            reach = massing_reach(mass, x, y, z, math.cos(angle), math.sin(angle), 4096.0);
            sights.append(reach);
            closest = min(closest, reach);
        }
        nearest.append(closest);
    }
    found["sight_med"] = critic_percentile(sights, 0.5);
    found["sight_p90"] = critic_percentile(sights, 0.9);
    found["near_med"] = critic_percentile(nearest, 0.5);
    found["lights_per"] = float(len(lamps)) / max(1.0, unit);
    gaps: list[float] = [];
    for (index, lamp) in enumerate(lamps[:400]) {
        closest = -1.0;
        for (other_index, other) in enumerate(lamps) {
            if other_index == index {
                continue;
            }
            gap = math.sqrt((lamp.x - other.x) ** 2 + (lamp.y - other.y) ** 2 + (lamp.z - other.z) ** 2);
            if closest < 0.0 or gap < closest {
                closest = gap;
            }
        }
        if closest >= 0.0 {
            gaps.append(closest);
        }
    }
    found["light_spacing"] = critic_percentile(gaps, 0.5);
    found["monsters_per"] = float(monsters) / max(1.0, unit);
    found["items_per"] = float(items) / max(1.0, unit);
    return found;
}

"""How many corpus spreads a measure lies from the corpus median (signed)."""
def critic_distance(name: str, value: float) -> float {
    if name not in CORPUS_SP {
        return 0.0;
    }
    quartiles = CORPUS_SP[name];
    spread = max(0.0001, (quartiles[2] - quartiles[0]) / 1.35);
    return (value - quartiles[1]) / spread;
}

"""The critic's score: the negative weighted sum of each measure's squared
distance from the corpus (each capped at 9)."""
def critic_score(measures: dict[str, float]) -> float {
    total = 0.0;
    for (name, weight) in CRITIC_WEIGHTS.items() {
        if name not in measures {
            continue;
        }
        distance = critic_distance(name, measures[name]);
        total += weight * min(9.0, distance * distance);
    }
    # Gameplay constraints supplement the corpus's geometric yardstick.
    # Targets saturate: adding more guns or quiet rooms is not endlessly
    # rewarded, and the score cannot excuse an unsafe supply forecast.
    goals = {
        "play_weapons": 3.0,
        "play_ammo_types": 2.0,
        "play_patterns": 3.0,
        "play_fight_coverage": 0.8,
        "play_cover": 0.35,
        "play_supplied": 1.0,
        "play_firing_lanes": 0.65,
        "play_optional_rewards": 1.0
    };
    for (name, target) in goals.items() {
        if name in measures {
            shortfall = max(0.0, target - measures[name]) / target;
            total += (8.0 if name == "play_supplied" else 2.0) * shortfall * shortfall;
        }
    }
    if "play_quiet" in measures {
        share = measures["play_quiet"];
        total += 8.0 * max(0.0, 0.15 - share) + 4.0 * max(0.0, share - 0.45);
    }
    total += 12.0 * measures.get("play_quiet_violations", 0.0);
    if measures.get("play_returns_wanted", 0.0) > 0.0 {
        total += 2.0 * max(0.0, 1.0 - measures.get("play_return_routes", 0.0)) ** 2;
    }
    return -total;
}
