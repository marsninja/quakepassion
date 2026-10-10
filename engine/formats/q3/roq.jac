"""Quake III RoQ films (code/client/cl_cin.c).

A RoQ file is an 8-byte header (the 0x1084 mark and the frame rate) and then
chunks: an id, a 24-bit size and a 16-bit argument, followed by the payload.
A picture is vector quantised. ROQ_CODEBOOK brings up to 256 2x2 cells (four
lumas and one chroma pair each, turned to RGB as they arrive) and up to 256
4x4 cells (four 2x2 cell numbers), which are also kept pixel-doubled as 8x8
cells. ROQ_QUAD_VQ then walks the picture's quad tree, 16x16 block by block:
two bits for each 8x8 quad say skip it, move it from the picture before, take
an 8x8 cell, or split into four 4x4 quads that each skip, move, take a 4x4
cell or take four 2x2 cells. Pictures alternate between the two halves of
one buffer, so a skipped quad keeps what the picture two back had there.
ZA_SOUND_MONO and ZA_SOUND_STEREO carry 22050 Hz sound as bytes indexing a
table of signed squares, each added to the sample before (RllDecode*).

The reader keeps cl_cin.c's shape: every chunk is copied to the front of one
65536-byte buffer together with the header of the chunk after it
(RoQInterrupt's cin.file), and is decoded from there. What a chunk does not
overwrite is left from earlier ones, which the original reads in two places
the shipped films reach: a codebook whose argument is 0 always takes 256
cells of each size, even when the chunk only holds the 2x2 ones, and the
header after the last chunk is whatever lay there."""
import from ..film { Film, FilmPicture }

glob ROQ_FILE: int = 0x1084,
     ROQ_QUAD_INFO: int = 0x1001,
     ROQ_CODEBOOK: int = 0x1002,
     ROQ_QUAD_VQ: int = 0x1011,
     ROQ_QUAD_JPEG: int = 0x1012,
     ROQ_QUAD_HANG: int = 0x1013,
     ROQ_PACKET: int = 0x1030,
     ZA_SOUND_MONO: int = 0x1020,
     ZA_SOUND_STEREO: int = 0x1021;

# CIN_RunCinematic's tfps: three pictures every 100 ms, whatever the header's
# rate says. S_RawSamples is always handed 22050 Hz, 16-bit sound.
glob ROQ_FRAME_RATE: int = 30,
     ROQ_SOUND_RATE: int = 22050;

# cin.file, and the largest picture cin.linbuf holds twice over.
glob ROQ_CHUNK_LIMIT: int = 65536,
     ROQ_PICTURE_LIMIT: int = 512 * 512;

"""A film being read chunk by chunk, as cinTable[] and cin are."""
obj RoqDecoder(Film) {
    has data: bytes = b"",
        # cin.file and where the next read from the film starts.
        scratch: bytearray = bytearray(),
        cursor: int = 0,
        # The chunk waiting to be run: roq_id, RoQFrameSize, roq_flags and
        # the argument's two signed bytes (roqF0, roqF1).
        roq_id: int = 0,
        chunk_size: int = 0,
        flags: int = 0,
        mean_x: int = 0,
        mean_y: int = 0,
        # RoQPlayed and inMemory (chunks left inside a ROQ_PACKET).
        played: int = 0,
        packets: int = 0,
        # numQuads: -1 until ROQ_QUAD_INFO, then the pictures decoded.
        num_quads: int = -1,
        finished: bool = False,
        # cin.linbuf (two pictures end to end), samplesPerLine, screenDelta,
        # the half holding the newest picture (buf) and whether it is new.
        linbuf: bytearray = bytearray(),
        samples_per_line: int = 0,
        screen_delta: int = 0,
        shown: int = 0,
        fresh: bool = False,
        # cin.qStatus: where each quad of the tree starts in a picture.
        quads: list[int] = [],
        quad_count: int = 0,
        # vq2, vq4 and vq8 as RGBA bytes: 16, 64 and 256 to a cell.
        vq2: bytearray = bytearray(),
        vq4: bytearray = bytearray(),
        vq8: bytearray = bytearray(),
        mcomp: list[int] = [],
        # ROQ_GenYUVTables and RllSetupTable.
        yy_tab: list[int] = [],
        ub_tab: list[int] = [],
        ug_tab: list[int] = [],
        vg_tab: list[int] = [],
        vr_tab: list[int] = [],
        sqr_table: list[int] = [],
        # Sound decoded since the last picture, and its channel count.
        sound: bytes = b"",
        sound_channels: int = 0;

    """CIN_RunCinematic's loop body until a picture is ready: chunks are run
    (codebooks decoded, sound gathered) up to the next ROQ_QUAD_VQ."""
    def next_picture() -> FilmPicture | None {
        while not self.finished {
            self.interrupt();
            if self.fresh {
                self.fresh = False;
                self.frame = self.num_quads;
                found = FilmPicture(
                    pixels=bytes(self.linbuf[self.shown:self.shown + self.screen_delta]),
                    samples=self.sound,
                    sound_rate=ROQ_SOUND_RATE,
                    sound_width=2,
                    sound_channels=self.sound_channels
                );
                self.sound = b"";
                return found;
            }
        }
        return None;
    }

    """RoQInterrupt: read the waiting chunk and the header after it, run the
    chunk, and make the following one the waiting chunk."""
    def interrupt() {
        # Sys_StreamedRead: a read past the end of the file leaves cin.file
        # as it was.
        count = max(0, min(self.chunk_size + 8, len(self.data) - self.cursor));
        scratch = self.scratch;
        data = self.data;
        start = self.cursor;
        for offset in range(count) {
            scratch[offset] = data[start + offset];
        }
        self.cursor += count;
        if self.played >= len(data) {
            self.finished = True;
            return;
        }
        framedata = 0;
        while True {
            self.run_chunk(framedata);
            if self.finished {
                return;
            }
            if self.played >= len(data) {
                self.finished = True;
                return;
            }
            framedata += self.chunk_size;
            if framedata + 8 > len(scratch) {
                raise ValueError("RoQ packet overruns its chunk");
            }
            self.roq_id = int(scratch[framedata]) + int(scratch[framedata + 1]) * 256;
            self.chunk_size = int(scratch[framedata + 2])
                + int(scratch[framedata + 3]) * 256
                + int(scratch[framedata + 4]) * 65536;
            self.flags = int(scratch[framedata + 6]) + int(scratch[framedata + 7]) * 256;
            self.mean_x = roq_signed_byte(int(scratch[framedata + 7]));
            self.mean_y = roq_signed_byte(int(scratch[framedata + 6]));
            if self.chunk_size > ROQ_CHUNK_LIMIT or self.roq_id == ROQ_FILE {
                self.finished = True;
                return;
            }
            if self.packets > 0 {
                # The chunks inside a ROQ_PACKET are already in cin.file.
                self.packets -= 1;
                framedata += 8;
                continue;
            }
            break;
        }
        self.played += self.chunk_size + 8;
    }

    """RoQInterrupt's switch on roq_id."""
    def run_chunk(framedata: int) {
        kind = self.roq_id;
        if kind == ROQ_QUAD_VQ {
            if self.num_quads < 0 {
                raise ValueError("RoQ picture before its ROQ_QUAD_INFO");
            }
            # Odd pictures go in the second half of linbuf and move quads
            # from the first; even ones the other way about.
            if self.num_quads % 2 == 1 {
                self.prepare_mcomp(-self.screen_delta);
                self.blit_quads(self.screen_delta, framedata);
                self.shown = self.screen_delta;
            } else {
                self.prepare_mcomp(self.screen_delta);
                self.blit_quads(0, framedata);
                self.shown = 0;
            }
            if self.num_quads == 0 {
                # The first picture is also the one "before" the second.
                linbuf = self.linbuf;
                delta = self.screen_delta;
                for offset in range(delta) {
                    linbuf[delta + offset] = linbuf[offset];
                }
            }
            self.num_quads += 1;
            self.fresh = True;
        } elif kind == ROQ_CODEBOOK {
            self.decode_codebook(framedata);
        } elif kind == ZA_SOUND_MONO {
            self.take_sound(roq_mono_sound(self.scratch, framedata, self.chunk_size, self.flags, self.sqr_table), 1);
        } elif kind == ZA_SOUND_STEREO {
            self.take_sound(roq_stereo_sound(self.scratch, framedata, self.chunk_size, self.flags, self.sqr_table), 2);
        } elif kind == ROQ_QUAD_INFO {
            if self.num_quads == -1 {
                self.read_quad_info(framedata);
                self.setup_quad();
            }
            if self.num_quads != 1 {
                self.num_quads = 0;
            }
        } elif kind == ROQ_PACKET {
            self.packets = self.flags;
            self.chunk_size = 0;
        } elif kind == ROQ_QUAD_HANG {
            self.chunk_size = 0;
        } elif kind != ROQ_QUAD_JPEG {
            self.finished = True;
        }
    }

    """S_RawSamples: sound waits for the picture it is read ahead of. A
    change of channel count starts again with the new layout."""
    def take_sound(samples: bytes, channels: int) {
        if channels != self.sound_channels {
            self.sound = b"";
            self.sound_channels = channels;
        }
        self.sound = self.sound + samples;
    }

    """readQuadInfo: the picture's size, and the buffer two of them fill."""
    def read_quad_info(framedata: int) {
        scratch = self.scratch;
        xsize = int(scratch[framedata]) + int(scratch[framedata + 1]) * 256;
        ysize = int(scratch[framedata + 2]) + int(scratch[framedata + 3]) * 256;
        if xsize < 8 or ysize < 8 or xsize * ysize > ROQ_PICTURE_LIMIT {
            raise ValueError("Invalid RoQ picture size");
        }
        self.width = xsize;
        self.height = ysize;
        self.samples_per_line = xsize * 4;
        self.screen_delta = ysize * self.samples_per_line;
        self.linbuf = bytearray(self.screen_delta * 2);
    }

    """setupQuad: the tree's quads in the order ROQ_QUAD_VQ codes them, 16x16
    block by block. The list ends where the original writes its end marks."""
    def setup_quad() {
        quads: list[int] = [];
        for y in range(0, self.height, 16) {
            for x in range(0, self.width, 16) {
                roq_recurse_quad(quads, x, y, 16, self.width, self.height, self.samples_per_line);
            }
        }
        cells = self.width * self.height // 16;
        cells += cells // 4;
        self.quads = quads;
        self.quad_count = min(len(quads), cells);
    }

    """RoQPrepMcomp: for each motion byte (x in the high four bits, y in the
    low), how far from a quad its source lies in the other picture."""
    def prepare_mcomp(other: int) {
        line = self.samples_per_line;
        pixel = 4;
        if self.width == self.height * 4 {
            pixel += pixel;
            line += line;
        }
        table = self.mcomp;
        for y in range(16) {
            down = (y + self.mean_y - 8) * line;
            for x in range(16) {
                table[x * 16 + y] = other - (down + (x + self.mean_x - 8) * pixel);
            }
        }
    }

    """decodeCodeBook for 32-bit pictures at full size: the 2x2 cells through
    yuv_to_rgb24, then each 4x4 cell as its four 2x2 cells, kept as it is
    (vq4) and with every pixel doubled each way (vq8, VQ2TO4)."""
    def decode_codebook(framedata: int) {
        two = 256;
        four = 256;
        if self.flags != 0 {
            two = self.flags >> 8;
            if two == 0 {
                two = 256;
            }
            four = self.flags & 255;
        }
        scratch = self.scratch;
        vq2 = self.vq2;
        vq4 = self.vq4;
        vq8 = self.vq8;
        yy_tab = self.yy_tab;
        ub_tab = self.ub_tab;
        ug_tab = self.ug_tab;
        vg_tab = self.vg_tab;
        vr_tab = self.vr_tab;
        position = framedata;
        target = 0;
        for cell in range(two) {
            u = int(scratch[position + 4]);
            v = int(scratch[position + 5]);
            red = vr_tab[v];
            green = ug_tab[u] + vg_tab[v];
            blue = ub_tab[u];
            for corner in range(4) {
                luma = yy_tab[int(scratch[position + corner])];
                vq2[target] = roq_colour(luma + red);
                vq2[target + 1] = roq_colour(luma + green);
                vq2[target + 2] = roq_colour(luma + blue);
                vq2[target + 3] = 255;
                target += 4;
            }
            position += 6;
        }
        small = 0;
        large = 0;
        for half in range(four * 2) {
            left = int(scratch[position]) * 16;
            right = int(scratch[position + 1]) * 16;
            position += 2;
            for row in range(2) {
                for offset in range(8) {
                    first = vq2[left + offset];
                    second = vq2[right + offset];
                    vq4[small + offset] = first;
                    vq4[small + 8 + offset] = second;
                    spot = large + (offset >> 2) * 8 + (offset & 3);
                    vq8[spot] = first;
                    vq8[spot + 4] = first;
                    vq8[spot + 32] = first;
                    vq8[spot + 36] = first;
                    vq8[spot + 16] = second;
                    vq8[spot + 20] = second;
                    vq8[spot + 48] = second;
                    vq8[spot + 52] = second;
                }
                small += 16;
                large += 64;
                left += 8;
                right += 8;
            }
        }
    }

    """blitVQQuad32fs: the picture's quads from two-bit codes, sixteen bits
    of them at a time, most significant first."""
    def blit_quads(base: int, framedata: int) {
        scratch = self.scratch;
        linbuf = self.linbuf;
        quads = self.quads;
        table = self.mcomp;
        line = self.samples_per_line;
        limit = len(scratch) - 6;
        position = framedata;
        remaining = 0;
        codes = 0;
        index = 0;
        count = self.quad_count;
        while index < count {
            if position > limit {
                raise ValueError("RoQ picture overruns its chunk");
            }
            if remaining == 0 {
                remaining = 7;
                codes = int(scratch[position]) + int(scratch[position + 1]) * 256;
                position += 2;
            } else {
                remaining -= 1;
            }
            code = codes & 0xC000;
            codes = (codes << 2) & 0xFFFF;
            at = base + quads[index];
            if code == 0x8000 {
                roq_blit(linbuf, at, self.vq8, int(scratch[position]) * 256, 32, 8, line);
                position += 1;
                index += 5;
            } elif code == 0xC000 {
                index += 1;
                for quarter in range(4) {
                    if remaining == 0 {
                        remaining = 7;
                        codes = int(scratch[position]) + int(scratch[position + 1]) * 256;
                        position += 2;
                    } else {
                        remaining -= 1;
                    }
                    code = codes & 0xC000;
                    codes = (codes << 2) & 0xFFFF;
                    at = base + quads[index];
                    if code == 0x8000 {
                        roq_blit(linbuf, at, self.vq4, int(scratch[position]) * 64, 16, 4, line);
                        position += 1;
                    } elif code == 0xC000 {
                        vq2 = self.vq2;
                        roq_blit(linbuf, at, vq2, int(scratch[position]) * 16, 8, 2, line);
                        roq_blit(linbuf, at + 8, vq2, int(scratch[position + 1]) * 16, 8, 2, line);
                        roq_blit(linbuf, at + line * 2, vq2, int(scratch[position + 2]) * 16, 8, 2, line);
                        roq_blit(linbuf, at + line * 2 + 8, vq2, int(scratch[position + 3]) * 16, 8, 2, line);
                        position += 4;
                    } elif code == 0x4000 {
                        roq_move(linbuf, at, at + table[int(scratch[position])], 16, 4, line);
                        position += 1;
                    }
                    index += 1;
                }
            } elif code == 0x4000 {
                roq_move(linbuf, at, at + table[int(scratch[position])], 32, 8, line);
                position += 1;
                index += 5;
            } else {
                index += 5;
            }
        }
    }
}

def:priv roq_signed_byte(value: int) -> int {
    return value - 256 if value > 127 else value;
}

"""yuv_to_rgb24's shift and clamp of one channel."""
def:priv roq_colour(value: int) -> int {
    if value < 0 {
        return 0;
    }
    return min(255, value >> 6);
}

"""recurseQuad: a quad of 8 or 4 pixels inside the picture is listed, and
everything above 4 is split into its four quarters, left to right, top
first."""
def:priv roq_recurse_quad(quads: list[int], x: int, y: int, size: int, width: int, height: int, line: int) {
    if x + size <= width and y + size <= height and size <= 8 {
        quads.append(y * line + x * 4);
    }
    if size != 4 {
        half = size >> 1;
        roq_recurse_quad(quads, x, y, half, width, height, line);
        roq_recurse_quad(quads, x + half, y, half, width, height, line);
        roq_recurse_quad(quads, x, y + half, half, width, height, line);
        roq_recurse_quad(quads, x + half, y + half, half, width, height, line);
    }
}

"""blit8_32, blit4_32 and blit2_32: `rows` rows of `width` bytes from a
codebook cell onto the picture."""
def:priv roq_blit(linbuf: bytearray, at: int, cells: bytearray, cell: int, width: int, rows: int, line: int) {
    for row in range(rows) {
        target = at + row * line;
        source = cell + row * width;
        for offset in range(width) {
            linbuf[target + offset] = cells[source + offset];
        }
    }
}

"""move8_32 and move4_32: a quad copied from the other picture. A source
outside the two pictures is a damaged film."""
def:priv roq_move(linbuf: bytearray, at: int, source: int, width: int, rows: int, line: int) {
    if source < 0 or source + (rows - 1) * line + width > len(linbuf) {
        raise ValueError("RoQ motion leaves the picture");
    }
    for row in range(rows) {
        target = at + row * line;
        origin = source + row * line;
        for offset in range(width) {
            linbuf[target + offset] = linbuf[origin + offset];
        }
    }
}

"""A sample kept to 16 signed bits, as the casts to short keep it."""
def:priv roq_short(value: int) -> int {
    return ((value + 32768) & 65535) - 32768;
}

"""RllDecodeStereoToStereo with unsigned output: the argument's high byte
starts the left channel and its low byte the right; `size` bytes make
size / 2 sample pairs."""
def:priv roq_stereo_sound(scratch: bytearray, framedata: int, size: int, flags: int, squares: list[int]) -> bytes {
    left = flags & 0xFF00;
    right = (flags & 0x00FF) << 8;
    pairs = size >> 1;
    output = bytearray(pairs * 4);
    for pair in range(pairs) {
        left = roq_short(left + squares[int(scratch[framedata + pair * 2])]);
        right = roq_short(right + squares[int(scratch[framedata + pair * 2 + 1])]);
        target = pair * 4;
        output[target] = left & 255;
        output[target + 1] = (left >> 8) & 255;
        output[target + 2] = right & 255;
        output[target + 3] = (right >> 8) & 255;
    }
    return bytes(output);
}

"""RllDecodeMonoToStereo, as RoQInterrupt hands it on: each sample is
written twice, and S_RawSamples is then told the buffer holds `size` mono
samples, so it plays the first half of the chunk, every sample twice."""
def:priv roq_mono_sound(scratch: bytearray, framedata: int, size: int, flags: int, squares: list[int]) -> bytes {
    previous = flags;
    output = bytearray(size * 2);
    for index in range(size) {
        if index % 2 == 0 {
            previous = roq_short(previous + squares[int(scratch[framedata + (index >> 1)])]);
        }
        output[index * 2] = previous & 255;
        output[index * 2 + 1] = (previous >> 8) & 255;
    }
    return bytes(output);
}

"""CIN_PlayCinematic, initRoQ and RoQ_init: check the file's mark, build the
colour and sound tables and make the first chunk the waiting one. `hold`
is CIN_hold: the last picture stays up."""
def open_roq(data: bytes, hold: bool = False) -> RoqDecoder {
    if len(data) < 16 or int(data[0]) + int(data[1]) * 256 != ROQ_FILE {
        raise ValueError("Invalid RoQ ID");
    }
    decoder = RoqDecoder(
        data=data,
        frame_rate=ROQ_FRAME_RATE,
        escape_skips=True,
        holds=hold,
        scratch=bytearray(ROQ_CHUNK_LIMIT + 8),
        cursor=16,
        played=24,
        vq2=bytearray(256 * 16),
        vq4=bytearray(256 * 64),
        vq8=bytearray(256 * 256),
        mcomp=[0] * 256
    );
    # ROQ_GenYUVTables.
    t_ub = (1.772 / 2.0) * 64.0 + 0.5;
    t_vr = (1.402 / 2.0) * 64.0 + 0.5;
    t_ug = (0.34414 / 2.0) * 64.0 + 0.5;
    t_vg = (0.71414 / 2.0) * 64.0 + 0.5;
    for index in range(256) {
        x = float(2 * index - 255);
        decoder.ub_tab.append(int(t_ub * x + 32.0));
        decoder.vr_tab.append(int(t_vr * x + 32.0));
        decoder.ug_tab.append(int(-t_ug * x));
        decoder.vg_tab.append(int(-t_vg * x + 32.0));
        decoder.yy_tab.append((index << 6) | (index >> 2));
    }
    # RllSetupTable.
    squares: list[int] = [0] * 256;
    for index in range(128) {
        squares[index] = index * index;
        squares[index + 128] = -(index * index);
    }
    decoder.sqr_table = squares;
    for offset in range(16) {
        decoder.scratch[offset] = data[offset];
    }
    decoder.roq_id = int(data[8]) + int(data[9]) * 256;
    decoder.chunk_size = int(data[10]) + int(data[11]) * 256 + int(data[12]) * 65536;
    decoder.flags = int(data[14]) + int(data[15]) * 256;
    return decoder;
}
