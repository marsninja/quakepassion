"""Microsoft PCM .wav files: the fmt chunk and where the samples lie, as
Quake III's background music reader finds them (snd_dma.c
S_StartBackgroundTrack with S_FindWavChunk)."""
import struct;

obj WavPcm {
    has rate: int = 0,
        width: int = 0,
        channels: int = 0,
        offset: int = 0,
        length: int = 0;

    """Bytes in one sample frame (every channel's sample)."""
    def frame_bytes() -> int {
        return self.width * self.channels;
    }
}

def:priv wav_u32(data: bytes, offset: int) -> int {
    return int(struct.unpack("<I", data[offset:offset + 4])[0]);
}

def:priv wav_u16(data: bytes, offset: int) -> int {
    return int(struct.unpack("<H", data[offset:offset + 2])[0]);
}

"""The PCM layout of a RIFF WAVE file. Chunks are word aligned; a data
chunk that claims more than the file holds keeps what is there."""
def parse_wav_pcm(data: bytes) -> WavPcm {
    if len(data) < 12 or data[0:4] != b"RIFF" or data[8:12] != b"WAVE" {
        raise ValueError("Not a RIFF WAVE file");
    }
    found = WavPcm();
    has_format = False;
    position = 12;
    while position + 8 <= len(data) {
        kind = data[position:position + 4];
        size = wav_u32(data, position + 4);
        body = position + 8;
        if kind == b"fmt " {
            if size < 16 or body + 16 > len(data) {
                raise ValueError("Short WAVE fmt chunk");
            }
            if wav_u16(data, body) != 1 {
                raise ValueError("Not a Microsoft PCM wav");
            }
            found.channels = wav_u16(data, body + 2);
            found.rate = int(wav_u32(data, body + 4));
            found.width = wav_u16(data, body + 14) // 8;
            has_format = True;
        } elif kind == b"data" {
            if not has_format {
                raise ValueError("WAVE data before its fmt chunk");
            }
            found.offset = body;
            found.length = min(size, len(data) - body);
            if found.width not in [1, 2] or found.channels not in [1, 2] or found.rate <= 0 {
                raise ValueError("Unsupported WAVE sample format");
            }
            # Whole sample frames only.
            found.length -= found.length % found.frame_bytes();
            return found;
        }
        position = body + size + (size & 1);
    }
    raise ValueError("No WAVE data chunk");
}

"""A WAVE file as a streaming decoder can take it. Quake's sounds are 8-bit,
and raylib's music streams decode WAVE at 16 or 32 bits only: an 8-bit file
opens and then plays nothing. An 8-bit file comes back rewritten at 16 bits
(unsigned bytes centred on 128 become signed words); any other file, and
anything that is not a PCM WAVE, comes back as it was."""
def streamable_wav(data: bytes) -> bytes {
    try {
        pcm = parse_wav_pcm(data);
    } except ValueError {
        return data;
    }
    if pcm.width != 1 {
        return data;
    }
    count = pcm.length;
    samples = bytearray(count * 2);
    for i in range(count) {
        # (byte - 128) * 256, as a little-endian signed word: the low byte is
        # zero and the high byte is the sample with its top bit flipped.
        samples[i * 2 + 1] = u8(int(data[pcm.offset + i]) ^ 128);
    }
    header = b"RIFF"
        + struct.pack("<I", 36 + count * 2)
        + b"WAVEfmt "
        + struct.pack(
            "<IHHIIHH",
            16,
            1,
            pcm.channels,
            pcm.rate,
            pcm.rate * pcm.channels * 2,
            pcm.channels * 2,
            16
        )
        + b"data"
        + struct.pack("<I", count * 2);
    return header + bytes(samples);
}

