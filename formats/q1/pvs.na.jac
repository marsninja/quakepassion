"""PVS (Potentially Visible Set) decode for BSP29 (Phase 2).

Each non-solid leaf carries a `vis_ofs` into the BSP's visdata, where its
visibility is stored as a run-length-encoded bit vector — one bit per other
leaf. Quake's RLE is simple: a non-zero byte is copied literally; a zero byte
is followed by a count of zero-bytes to emit (long stretches of "can't see
this" compress to two bytes). Decoding yields a flat bit vector; bit `i`
means leaf `i + 1` is potentially visible.

This is what turns the phase-1 portal flood into real culling: `VisPass`
floods through Portal edges, intersected with the leaf's PVS. Pure data code.
Bodies live in impl/pvs.na.impl.jac."""


"""Bytes of PVS bit vector for a map with `num_leafs` visible leafs:
ceil(num_leafs / 8)."""
def vis_row_bytes(num_leafs: int) -> int;

"""Decompress a leaf's RLE PVS starting at `vis_ofs` into a flat bit vector of
exactly `row_bytes` bytes."""
def decompress_vis(visdata: bytes, vis_ofs: int, row_bytes: int) -> bytes;

"""Is bit `i` set in a decompressed PVS row? (bit i ↔ leaf i+1.)"""
def vis_bit(row: bytes, i: int) -> bool;
