"""Every Q3 map's patches through R_SubdividePatchToGrid and R_StitchAllPatches:
each map must parse, every patch face must index its own vertices, and the
triangle count is set beside what eight fixed steps a quadratic piece gave.
QP_SUBDIVISIONS sets r_subdivisions (default 4).

    jac build scripts/validate_patches.jac --native -o .jac/validate-patches
    DYLD_LIBRARY_PATH=vendor .jac/validate-patches
"""
import os;
import from engine.assets.pk3 { Pk3Assets }
import from engine.formats.q3.bsp { parse_q3 }

with entry {
    subdivisions = float(os.getenv("QP_SUBDIVISIONS", "4"));
    pk3 = Pk3Assets();
    pk3.open(os.getenv("HOME", "") + "/quake-assets/baseq3");
    maps = 0;
    fixed_total = 0;
    drawn_total = 0;
    for name in sorted(pk3.owners.keys()) {
        if not name.startswith("maps/") or not name.endswith(".bsp") {
            continue;
        }
        bsp = parse_q3(pk3.read(name), subdivisions);
        patches = 0;
        fixed = 0;
        drawn = 0;
        flat = 0;
        for face in bsp.faces {
            if not face.patch {
                continue;
            }
            patches += 1;
            assert len(face.vertices) >= 4 and len(face.indices) % 3 == 0 and len(face.indices) >= 6 , name;
            assert max(face.indices) < len(face.vertices) and min(face.indices) >= 0 , name;
            assert len(face.uv) == len(face.vertices) * 2 and len(face.colors) == len(face.vertices) * 4 , name;
            fixed += ((face.patch_width - 1) // 2) * ((face.patch_height - 1) // 2) * 128;
            drawn += len(face.indices) // 3;
            if len(face.vertices) == 4 {
                flat += 1;
            }
        }
        maps += 1;
        fixed_total += fixed;
        drawn_total += drawn;
        print("PATCHES", name, "patches", patches, "flat", flat, "triangles", drawn, "at eight steps", fixed);
    }
    pk3.close();
    assert maps > 0;
    print("PATCH MAPS PASS", maps, "triangles", drawn_total, "at eight steps", fixed_total);
}
