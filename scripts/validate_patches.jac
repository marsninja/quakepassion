"""Every Q3 map's patches through R_SubdividePatchToGrid, R_StitchAllPatches
and R_FixSharedVertexLodError: each map must parse, every patch face must
index its own vertices and carry a normal for each and an error for each
column and row, and the triangle count is set beside what eight fixed steps
a quadratic piece gave and beside the fewest a distant view draws
(RB_SurfaceGrid with nothing allowed). QP_SUBDIVISIONS sets r_subdivisions
(default 4).

    jac build scripts/validate_patches.jac --native -o .jac/validate-patches
    DYLD_LIBRARY_PATH=vendor .jac/validate-patches
"""
import os;
import from engine.assets.pk3 { Pk3Assets }
import from engine.formats.q3.bsp { parse_q3 }
import from engine.render.world_mesh { grid_lines, grid_steps }

with entry {
    subdivisions = float(os.getenv("QP_SUBDIVISIONS", "4"));
    pk3 = Pk3Assets();
    pk3.open(os.getenv("HOME", "") + "/quake-assets/baseq3");
    maps = 0;
    fixed_total = 0;
    drawn_total = 0;
    coarse_total = 0;
    thinned_total = 0;
    patch_total = 0;
    bare = 0;
    for name in sorted(pk3.owners.keys()) {
        if not name.startswith("maps/") or not name.endswith(".bsp") {
            continue;
        }
        bsp = parse_q3(pk3.read(name), subdivisions);
        patches = 0;
        fixed = 0;
        drawn = 0;
        coarse = 0;
        thinned = 0;
        flat = 0;
        for face in bsp.faces {
            if not face.patch {
                continue;
            }
            patches += 1;
            assert len(face.vertices) >= 4 and len(face.indices) % 3 == 0 and len(face.indices) >= 6 , name;
            assert max(face.indices) < len(face.vertices) and min(face.indices) >= 0 , name;
            assert len(face.uv) == len(face.vertices) * 2 and len(face.colors) == len(face.vertices) * 4 , name;
            assert face.grid_width * face.grid_height == len(face.vertices) and len(face.normals) == len(face.vertices) , name;
            assert len(face.width_errors) == face.grid_width and len(face.height_errors) == face.grid_height , name;
            assert (face.grid_width - 1) * (face.grid_height - 1) * 6 == len(face.indices) , name;
            for normal in face.normals {
                # MakeMeshNormals leaves a vertex with no two usable edges without one.
                if normal.length() < 0.99 {
                    bare += 1;
                }
            }
            fixed += ((face.patch_width - 1) // 2) * ((face.patch_height - 1) // 2) * 128;
            drawn += len(face.indices) // 3;
            coarse += (len(grid_lines(face.width_errors, 0.0)) - 1) * (len(grid_lines(face.height_errors, 0.0)) - 1) * 2;
            if grid_steps(face.width_errors, face.height_errors) {
                thinned += 1;
            }
            if len(face.vertices) == 4 {
                flat += 1;
            }
        }
        maps += 1;
        fixed_total += fixed;
        drawn_total += drawn;
        coarse_total += coarse;
        thinned_total += thinned;
        patch_total += patches;
        print("PATCHES", name, "patches", patches, "flat", flat, "thinning", thinned, "triangles", drawn, "coarsest", coarse, "at eight steps", fixed);
    }
    pk3.close();
    assert maps > 0;
    print(
        "PATCH MAPS PASS", maps, "patches", patch_total, "thinning", thinned_total, "triangles", drawn_total,
        "coarsest", coarse_total, "at eight steps", fixed_total, "vertices without a normal", bare
    );
}
