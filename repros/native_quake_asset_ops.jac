"""Asset-loader operations accepted by Jac but rejected by 0.37.19 native build.
Run: jac build repros/native_quake_asset_ops.jac --native -o /tmp/qp-asset-repro
"""
import os;

def directory_names(path: str) -> int {
    count = 0;
    for filename in sorted(os.listdir(path)) { count += len(filename); }
    return count;
}
def entity_origin(fields: dict[str, str]) -> float {
    coords = fields.get("origin", "0 0 0").split();
    return float(coords[0]);
}
def lightmap_byte(value: int) -> int {
    pixels = bytearray(b"\xff\xff\xff\xff");
    pixels[0] = value;
    return int(pixels[0]);
}
with entry {
    assert directory_names(".") > 0;
    assert entity_origin({"origin": "12 34 56"}) == 12.0;
    assert lightmap_byte(128) == 128;
    print("native asset operations passed");
}
