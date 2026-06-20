"""Implementations for PVS decode. Declarations live in pvs.na.jac."""

impl vis_row_bytes(num_leafs: int) -> int {
    return (num_leafs + 7) >> 3;
}

impl decompress_vis(visdata: bytes, vis_ofs: int, row_bytes: int) -> bytes {
    out: list[int] = [];
    inp = vis_ofs;
    while len(out) < row_bytes {
        b = visdata[inp];
        if b != 0 {
            # literal byte
            out.append(b);
            inp += 1;
        } else {
            # zero run: the next byte is how many zero-bytes to emit
            c = visdata[inp + 1];
            inp += 2;
            while c > 0 and len(out) < row_bytes {
                out.append(0);
                c -= 1;
            }
        }
    }
    return bytes(out);
}

impl vis_bit(row: bytes, i: int) -> bool {
    byte_idx = i >> 3;
    if byte_idx >= len(row) {
        return False;
    }
    return ((row[byte_idx] >> (i & 7)) & 1) != 0;
}
