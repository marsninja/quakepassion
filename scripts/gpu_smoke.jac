"""GPU foundation smoke: an indexed triangle, a triangle whose positions come
from a float texture through texelFetch, and a row of instanced quads, drawn
with engine/render/gpu.jac inside the normal 3D view; saves gpu_smoke.png in
the working directory (raylib writes screenshots there).

    jac build scripts/gpu_smoke.jac --native -o .jac/gpu-smoke
    DYLD_LIBRARY_PATH=vendor .jac/gpu-smoke
"""
import struct;
import from engine.render.renderer { Renderer }
import from engine.render.gpu {
    GpuMesh,
    GpuProgram,
    VertexAttribute,
    GL_FLOAT,
    GL_UNSIGNED_BYTE,
    view_projection,
    upload_float_texture,
    pack_floats,
    pack_indices
}
import from engine.math.vec3 { Vec3 }
import from vendor.raylib { def rlDisableBackfaceCulling -> None;  def rlEnableBackfaceCulling -> None; }

glob PLAIN_VS: str = "#version 330\nin vec3 position; in vec4 color; uniform mat4 mvp; out vec4 tint;\nvoid main(){ tint=color; gl_Position=mvp*vec4(position,1.0); }\n",
     PLAIN_FS: str = "#version 330\nin vec4 tint; out vec4 finalColor;\nvoid main(){ finalColor=tint; }\n",
     FETCH_VS: str = "#version 330\nin float corner; uniform mat4 mvp; uniform sampler2D frames; uniform int frame;\nvoid main(){ vec4 p=texelFetch(frames, ivec2(int(corner), frame), 0); gl_Position=mvp*vec4(p.xyz,1.0); }\n",
     FETCH_FS: str = "#version 330\nout vec4 finalColor;\nvoid main(){ finalColor=vec4(0.2,0.6,1.0,1.0); }\n",
     INSTANCE_VS: str = "#version 330\nin vec2 corner; in vec4 place; uniform mat4 mvp;\nvoid main(){ gl_Position=mvp*vec4(place.x+corner.x*place.w, place.y, place.z+corner.y*place.w, 1.0); }\n",
     INSTANCE_FS: str = "#version 330\nout vec4 finalColor;\nvoid main(){ finalColor=vec4(1.0,0.8,0.1,1.0); }\n";

with entry {
    renderer = Renderer();
    renderer.open_window();
    plain = GpuProgram();
    plain.load(PLAIN_VS, PLAIN_FS);
    triangle = GpuMesh();
    vertices = bytearray();
    for corner in [(0.0, -30.0, -20.0, 255, 0, 0), (0.0, 30.0, -20.0, 0, 255, 0), (0.0, 0.0, 30.0, 0, 0, 255)] {
        vertices.extend(struct.pack("<fff", corner[0], corner[1], corner[2]));
        vertices.extend(bytes([corner[3], corner[4], corner[5], 255]));
    }
    triangle.upload(
        bytes(vertices),
        16,
        [
            VertexAttribute(location=plain.attribute("position"), components=3, kind=GL_FLOAT),
            VertexAttribute(location=plain.attribute("color"), components=4, kind=GL_UNSIGNED_BYTE, normalized=True, offset=12)
        ],
        indices=pack_indices([0, 1, 2])
    );
    fetch = GpuProgram();
    fetch.load(FETCH_VS, FETCH_FS);
    frames = upload_float_texture(
        pack_floats([0.0, 40.0, -20.0, 1.0, 0.0, 70.0, -20.0, 1.0, 0.0, 55.0, 20.0, 1.0,
                     0.0, 40.0, 0.0, 1.0, 0.0, 70.0, 0.0, 1.0, 0.0, 55.0, 40.0, 1.0]),
        3,
        2
    );
    fetched = GpuMesh();
    fetched.upload(
        pack_floats([0.0, 1.0, 2.0]),
        4,
        [VertexAttribute(location=fetch.attribute("corner"), components=1, kind=GL_FLOAT)]
    );
    instanced = GpuProgram();
    instanced.load(INSTANCE_VS, INSTANCE_FS);
    quads = GpuMesh();
    quads.upload(
        pack_floats([-0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, 0.5]),
        8,
        [VertexAttribute(location=instanced.attribute("corner"), components=2, kind=GL_FLOAT)]
    );
    quads.upload_instances(
        8, 16, [VertexAttribute(location=instanced.attribute("place"), components=4, kind=GL_FLOAT)]
    );
    print("PROGRAMS", plain.id, fetch.id, instanced.id, "ATTRS", plain.attribute("position"), plain.attribute("color"), fetch.attribute("corner"), instanced.attribute("corner"), instanced.attribute("place"), "MESH", triangle.vao, triangle.vbo, triangle.ibo);
    places: list[float] = [];
    for i in range(5) {
        places.extend([0.0, -60.0 + float(i) * 12.0, -40.0, 8.0]);
    }
    quads.set_instances(pack_floats(places));
    for frame in range(3) {
        renderer.begin_frame(Vec3(x=-120.0), 0.0, 0.0);
        rlDisableBackfaceCulling();
        mvp = view_projection();
        plain.begin();
        plain.set_matrix("mvp", mvp);
        triangle.bind();
        triangle.draw_indices(0, 3);
        triangle.unbind();
        plain.end();
        fetch.begin();
        fetch.set_matrix("mvp", mvp);
        fetch.set_texture("frames", 0, frames);
        fetch.set_int("frame", 1);
        fetched.bind();
        fetched.draw_vertices(0, 3);
        fetched.unbind();
        fetch.end();
        instanced.begin();
        instanced.set_matrix("mvp", mvp);
        quads.bind();
        quads.draw_instances(0, 6, 5);
        quads.unbind();
        instanced.end();
        rlEnableBackfaceCulling();
        renderer.end_scene();
        if frame == 2 {
            renderer.screenshot("gpu_smoke.png");
        }
        renderer.end_frame();
    }
    renderer.close();
    print("GPU SMOKE DONE");
}
