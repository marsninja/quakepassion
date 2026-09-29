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
