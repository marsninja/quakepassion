"""C buffer conversion must also run for foreign calls returning a struct.
Build the companion C source as vendor/libqp_ffi_probe.dylib (macOS) or .so.
Both calls must observe first byte 127; the struct must also contain 1 and 2.
"""
import from vendor.qp_ffi_probe {
    obj ProbeResult {
        has first: i64,
            second: i64,
            length: i64;
    }  def scalar_first(data: bytes, length: i32) -> i32;  def struct_bytes(
        data: bytes, length: i32
    ) -> ProbeResult;
}

with entry {
    data = b"\x7f\x01";
    scalar = scalar_first(data, i32(len(data)));
    result = struct_bytes(data, i32(len(data)));
    print("scalar", int(scalar));
    print("struct", int(result.first), int(result.second), int(result.length));
    assert int(scalar) == 127;
    assert int(result.first) == 127
        and int(result.second) == 1
        and int(result.length) == 2;
}
