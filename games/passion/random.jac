"""Counter-based deterministic randomness with labelled, independent substreams.

Every value is a pure function of (key, counter), so a subsystem that draws more
or fewer numbers never shifts another subsystem's results. Arithmetic stays in
32-bit words split into 16-bit halves, keeping native and interpreted results
identical without relying on integer overflow behavior.
"""

glob MASK32: int = 4294967295;

def mul32(a: int, b: int) -> int {
    low = a * (b & 65535);
    high = ((a * (b >> 16)) & 65535) << 16;
    return (low + high) & MASK32;
}

# Wellons' lowbias32 finalizer: full avalanche on 32-bit words.
def mix32(value: int) -> int {
    x = value & MASK32;
    x = x ^ (x >> 16);
    x = mul32(x, 2146121005);
    x = x ^ (x >> 15);
    x = mul32(x, 2221713035);
    x = x ^ (x >> 16);
    return x;
}

def hash_label(key: int, label: str) -> int {
    value = mix32(key ^ 2166136261);
    for character in label {
        value = mul32(value ^ ord(character), 16777619);
    }
    return mix32(value ^ len(label));
}

obj Stream {
    has key: int,
        counter: int = 0;

    def derive(label: str) -> Stream {
        return Stream(key=hash_label(self.key, label));
    }

    def child(label: str, index: int) -> Stream {
        return Stream(key=mix32(hash_label(self.key, label) ^ mix32(index + 40503)));
    }

    def word -> int {
        self.counter += 1;
        return mix32(self.key ^ mix32(self.counter * 2654435761));
    }

    # Unbiased bounded integers by rejecting the incomplete top interval.
    def below(limit: int) -> int {
        if limit <= 0 {
            raise ValueError("Empty random choice");
        }
        threshold = (4294967296 - limit) % limit;
        while True {
            value = self.word();
            if value >= threshold {
                return value % limit;
            }
        }
        return 0;
    }

    def between(low: int, high: int) -> int {
        return low + self.below(high - low + 1);
    }

    def unit -> float {
        return float(self.word()) / 4294967296.0;
    }

    def uniform(low: float, high: float) -> float {
        return low + (high - low) * self.unit();
    }

    def chance(probability: float) -> bool {
        return self.unit() < probability;
    }

    def weighted(weights: list[float]) -> int {
        total = 0.0;
        for weight in weights {
            total += max(0.0, weight);
        }
        if total <= 0.0 {
            raise ValueError("Weighted choice needs a positive weight");
        }
        target = self.unit() * total;
        for index in range(len(weights)) {
            target -= max(0.0, weights[index]);
            if target < 0.0 {
                return index;
            }
        }
        for index in range(len(weights) - 1, -1, -1) {
            if weights[index] > 0.0 {
                return index;
            }
        }
        return 0;
    }

    def order(count: int) -> list[int] {
        result = list(range(count));
        for index in range(count - 1, 0, -1) {
            other = self.below(index + 1);
            swap = result[index];
            result[index] = result[other];
            result[other] = swap;
        }
        return result;
    }
}

def stream_for(seed: int, label: str) -> Stream {
    return Stream(key=hash_label(mix32(seed), "passion")).derive(label);
}
