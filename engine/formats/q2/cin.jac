"""Quake II .cin cinematics (client/cl_cin.c).

A cinematic starts with five little-endian i32s: the frame width and height
and the sound's rate, sample width (bytes) and channel count. Then come 256
rows of 256 byte counts, one order-1 Huffman tree per preceding pixel value
(Huff1TableInit). Each frame is a command word (2 ends the film, 1 means a
new 768-byte palette follows), the compressed size, the Huffman-coded 8-bit
picture (Huff1Decompress) and the frame's share of the sound: frame n holds
samples n*rate/14 up to (n+1)*rate/14, the films running at 14 frames a
second (SCR_ReadNextFrame)."""
import struct;

glob CIN_FRAME_RATE: int = 14;
glob CIN_MAX_COMPRESSED: int = 131072;

obj CinHeader {
    has width: int = 0,
        height: int = 0,
        sound_rate: int = 0,
        sound_width: int = 0,
        sound_channels: int = 0;
}

"""One decoded frame: its palette indices, the palette in force once it was
read, and its sound samples as they are stored in the file."""
obj CinFrame {
    has index: int = 0,
        pixels: bytes = b"",
        palette: bytes = b"",
        samples: bytes = b"";
}

"""A cinematic being read frame by frame, as cl.cinematic_file is. `nodes`
holds the 256 trees' internal nodes, 512 entries (two children for each of
nodes 256..511) per preceding value; `roots` is numhnodes1."""
obj CinDecoder {
    has data: bytes = b"",
        header: CinHeader = CinHeader(),
        nodes: list[int] = [],
        roots: list[int] = [],
        cursor: int = 0,
        frame: int = 0,
        palette: bytes = b"",
        finished: bool = False;

    """SCR_ReadNextFrame: the next frame, or None at the end marker or the
    end of the file."""
    def next_frame() -> CinFrame | None {
        if self.finished {
            return None;
        }
        # Anything short of a whole command word ends the film.
        if self.cursor + 4 > len(self.data) {
            self.finished = True;
            return None;
        }
        command = cin_i32(self.data, self.cursor);
        self.cursor += 4;
        if command == 2 {
            self.finished = True;
            return None;
        }
        if command == 1 {
            cin_require(self.data, self.cursor, 768);
            self.palette = self.data[self.cursor:self.cursor + 768];
            self.cursor += 768;
        }
        size = cin_i32(self.data, self.cursor);
        self.cursor += 4;
        if size > CIN_MAX_COMPRESSED or size < 1 {
            raise ValueError("Bad compressed frame size");
        }
        cin_require(self.data, self.cursor, size);
        compressed = self.data[self.cursor:self.cursor + size];
        self.cursor += size;
        header = self.header;
        start = self.frame * header.sound_rate // CIN_FRAME_RATE;
        end = (self.frame + 1) * header.sound_rate // CIN_FRAME_RATE;
        length = (end - start) * header.sound_width * header.sound_channels;
        # FS_Read of the last frame's sound may come up short; keep what is there.
        stop = min(len(self.data), self.cursor + length);
        samples = self.data[self.cursor:stop];
        self.cursor = stop;
        pixels = huff1_decompress(self.nodes, self.roots, compressed);
        if len(pixels) != header.width * header.height {
            raise ValueError("Cinematic frame has the wrong size");
        }
        found = CinFrame(
            index=self.frame, pixels=pixels, palette=self.palette, samples=samples
        );
        self.frame += 1;
        return found;
    }
}

def:priv cin_require(data: bytes, offset: int, size: int) {
    if offset < 0 or size < 0 or offset > len(data) or size > len(data) - offset {
        raise ValueError("Truncated cinematic");
    }
}

def:priv cin_i32(data: bytes, offset: int) -> int {
    cin_require(data, offset, 4);
    return int(struct.unpack("<i", data[offset:offset + 4])[0]);
}

"""SCR_PlayCinematic's header and Huff1TableInit's 256 trees."""
def open_cin(data: bytes) -> CinDecoder {
    header = CinHeader(
        width=cin_i32(data, 0),
        height=cin_i32(data, 4),
        sound_rate=cin_i32(data, 8),
        sound_width=cin_i32(data, 12),
        sound_channels=cin_i32(data, 16)
    );
    if header.width < 1 or header.width > 4096 or header.height < 1 or header.height > 4096 {
        raise ValueError("Invalid cinematic size");
    }
    if header.sound_rate < 0 or header.sound_rate > 96000
        or header.sound_width not in [1, 2]
        or header.sound_channels not in [1, 2] {
        raise ValueError("Invalid cinematic sound format");
    }
    cin_require(data, 20, 65536);
    nodes: list[int] = [];
    roots: list[int] = [];
    for previous in range(256) {
        row = 20 + previous * 256;
        tree = huff1_tree(data[row:row + 256]);
        roots.append(tree[0]);
        nodes.extend(tree[1:]);
    }
    return CinDecoder(
        data=data,
        header=header,
        nodes=nodes,
        roots=roots,
        cursor=20 + 65536,
        palette=bytes(768)
    );
}

"""One Huff1TableInit row: the tree's root (numhnodes1) followed by its 512
child slots. SmallestNode1 takes the lowest unused non-zero count, the
earliest node winning a tie."""
def huff1_tree(counts: bytes) -> list[int] {
    count: list[int] = [0] * 512;
    used: list[bool] = [False] * 512;
    for value in range(256) {
        count[value] = int(counts[value]);
    }
    children: list[int] = [0] * 512;
    total = 256;
    while total != 511 {
        slot = (total - 256) * 2;
        first = huff1_smallest(count, used, total);
        children[slot] = first;
        if first == -1 {
            break;
        }
        second = huff1_smallest(count, used, total);
        children[slot + 1] = second;
        if second == -1 {
            break;
        }
        count[total] = count[first] + count[second];
        total += 1;
    }
    tree: list[int] = [total - 1];
    tree.extend(children);
    return tree;
}

def:priv huff1_smallest(count: list[int], used: list[bool], total: int) -> int {
    best = 99999999;
    chosen = -1;
    for current in range(total) {
        if used[current] or count[current] == 0 {
            continue;
        }
        if count[current] < best {
            best = count[current];
            chosen = current;
        }
    }
    if chosen != -1 {
        used[chosen] = True;
    }
    return chosen;
}

"""Huff1Decompress: a little-endian output length, then bits read low bit
first. Each value found selects the tree for the next one, starting from
tree 0."""
def huff1_decompress(nodes: list[int], roots: list[int], block: bytes) -> bytes {
    if len(block) < 4 {
        raise ValueError("Truncated cinematic frame");
    }
    remaining = int(block[0]) | (int(block[1]) << 8) | (int(block[2]) << 16) | (int(block[3]) << 24);
    if remaining > 16777216 {
        raise ValueError("Cinematic frame too large");
    }
    output = bytearray(remaining);
    written = 0;
    table = 0;
    current = roots[0];
    position = 4;
    limit = len(block);
    while remaining > 0 {
        # The original reads one byte past a block that ends on a leaf.
        bits = int(block[position]) if position < limit else 0;
        if position > limit {
            raise ValueError("Cinematic frame overread");
        }
        position += 1;
        for bit in range(8) {
            if current < 256 {
                output[written] = current;
                written += 1;
                remaining -= 1;
                if remaining == 0 {
                    break;
                }
                table = current * 512;
                current = roots[current];
            }
            slot = table + (current - 256) * 2 + (bits & 1);
            if current < 256 or slot >= len(nodes) {
                raise ValueError("Corrupt cinematic Huffman tree");
            }
            current = nodes[slot];
            bits = bits >> 1;
        }
    }
    return bytes(output);
}
