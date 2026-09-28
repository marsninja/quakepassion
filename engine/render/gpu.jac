"""GPU-resident geometry through rlgl's vertex array API.

Static geometry is uploaded once into vertex buffers and drawn with one call
per batch; per frame only small data (index ranges, uniforms, instance
records) crosses to the GPU. rlgl draws indexed geometry with 16-bit
indices, so a mesh holds at most 65535 vertices: large geometry is split
into chunks of that size.

Every raylib call stays behind the render layer; this module is the shared
foundation the world, model and effect renderers build on.
"""
import struct;
import from vendor.raylib {
    obj Matrix {
        has m0: f32,
            m4: f32,
            m8: f32,
            m12: f32,
            m1: f32,
            m5: f32,
            m9: f32,
            m13: f32,
            m2: f32,
            m6: f32,
            m10: f32,
            m14: f32,
            m3: f32,
            m7: f32,
            m11: f32,
            m15: f32;
    }  def rlLoadVertexArray -> u32;  def rlEnableVertexArray(vaoId: u32) -> bool;  def rlDisableVertexArray -> None;  def rlLoadVertexBuffer(
        buffer: bytes, size: i32, dynamic: bool
    ) -> u32;  def rlLoadVertexBufferElement(
        buffer: bytes, size: i32, dynamic: bool
    ) -> u32;  def rlUpdateVertexBuffer(
        bufferId: u32, data: bytes, dataSize: i32, offset: i32
    ) -> None;  def rlUpdateVertexBufferElements(
        id: u32, data: bytes, dataSize: i32, offset: i32
    ) -> None;  def rlEnableVertexBuffer(id: u32) -> None;  def rlDisableVertexBuffer -> None;  def rlSetVertexAttribute(
        index: u32, compSize: i32, kind: i32, normalized: bool, stride: i32, offset: i32
    ) -> None;  def rlEnableVertexAttribute(index: u32) -> None;  def rlSetVertexAttributeDivisor(
        index: u32, divisor: i32
    ) -> None;  def rlDrawVertexArray(offset: i32, count: i32) -> None;  def rlDrawVertexArrayElements(
        offset: i32, count: i32, buffer: u64
    ) -> None;  def rlDrawVertexArrayInstanced(
        offset: i32, count: i32, instances: i32
    ) -> None;  def rlDrawVertexArrayElementsInstanced(
        offset: i32, count: i32, buffer: u64, instances: i32
    ) -> None;  def rlUnloadVertexArray(vaoId: u32) -> None;  def rlUnloadVertexBuffer(
        vboId: u32
    ) -> None;  def rlLoadShaderProgram(vsCode: str, fsCode: str) -> u32;  def rlUnloadShaderProgram(
        id: u32
    ) -> None;  def rlGetLocationUniform(shaderId: u32, uniformName: str) -> i32;  def rlGetLocationAttrib(
        shaderId: u32, attribName: str
    ) -> i32;  def rlEnableShader(id: u32) -> None;  def rlDisableShader -> None;  def rlSetUniform(
        locIndex: i32, value: bytes, uniformType: i32, count: i32
    ) -> None;  def rlSetUniformMatrix(locIndex: i32, mat: Matrix) -> None;  def rlGetMatrixModelview -> Matrix;  def rlGetMatrixProjection -> Matrix;  def MatrixMultiply(
        left: Matrix, right: Matrix
    ) -> Matrix;  def rlDrawRenderBatchActive -> None;  def rlActiveTextureSlot(
        slot: i32
    ) -> None;  def rlEnableTexture(id: u32) -> None;  def rlDisableTexture -> None;  def rlLoadTexture(
        data: bytes, width: i32, height: i32, format: i32, mipmapCount: i32
    ) -> u32;  def rlUpdateTexture(
        id: u32, offsetX: i32, offsetY: i32, width: i32, height: i32, format: i32, data: bytes
    ) -> None;  def rlUnloadTexture(id: u32) -> None;  def rlTextureParameters(
        id: u32, param: i32, value: i32
    ) -> None;
}

# rlgl data types (RL_FLOAT, RL_UNSIGNED_BYTE) for vertex attributes.
glob GL_FLOAT: int = 5126,
     GL_UNSIGNED_BYTE: int = 5121,
     GL_UNSIGNED_SHORT: int = 5123;

# rlgl uniform types (rlShaderUniformDataType).
glob UNIFORM_FLOAT: int = 0,
     UNIFORM_VEC2: int = 1,
     UNIFORM_VEC3: int = 2,
     UNIFORM_VEC4: int = 3,
     UNIFORM_INT: int = 4,
     UNIFORM_SAMPLER2D: int = 8;

# rlPixelFormat: 32-bit float RGBA texels, for data read with texelFetch.
glob PIXEL_RGBA32F: int = 10,
     PIXEL_RGBA8: int = 7;

# The most vertices one 16-bit indexed mesh can address.
glob MESH_VERTEX_LIMIT: int = 65535;

"""One vertex attribute: `location` in the shader, `components` values of
`kind` (GL_FLOAT or GL_UNSIGNED_BYTE) at `offset` bytes into the vertex."""
obj VertexAttribute {
    has location: int,
        components: int,
        kind: int,
        normalized: bool = False,
        offset: int = 0,
        divisor: int = 0;
}

"""A vertex array: one interleaved vertex buffer described by `attributes`
with `stride` bytes per vertex, and an optional 16-bit index buffer.
`instances` is a second, per-instance vertex buffer for instanced draws."""
obj GpuMesh {
    has vao: int = 0,
        vbo: int = 0,
        ibo: int = 0,
        instances: int = 0,
        stride: int = 0,
        vertex_count: int = 0,
        index_capacity: int = 0,
        instance_capacity: int = 0;

    """Upload `vertices` (interleaved, `stride` bytes each) and describe them
    with `attributes`. `index_capacity` reserves a dynamic index buffer of
    that many 16-bit indices (0 for none); `indices` fills a static one."""
    def upload(
        vertices: bytes,
        stride: int,
        attributes: list[VertexAttribute],
        indices: bytes = b"",
        index_capacity: int = 0,
        dynamic: bool = False
    ) {
        self.stride = stride;
        self.vertex_count = len(vertices) // stride if stride > 0 else 0;
        self.vao = int(rlLoadVertexArray());
        rlEnableVertexArray(u32(self.vao));
        self.vbo = int(rlLoadVertexBuffer(vertices, i32(len(vertices)), dynamic));
        for attribute in attributes {
            rlSetVertexAttribute(
                u32(attribute.location),
                i32(attribute.components),
                i32(attribute.kind),
                attribute.normalized,
                i32(stride),
                i32(attribute.offset)
            );
            rlEnableVertexAttribute(u32(attribute.location));
        }
        if indices {
            self.ibo = int(rlLoadVertexBufferElement(indices, i32(len(indices)), False));
            self.index_capacity = len(indices) // 2;
        } elif index_capacity > 0 {
            self.ibo = int(
                rlLoadVertexBufferElement(
                    bytes(index_capacity * 2), i32(index_capacity * 2), True
                )
            );
            self.index_capacity = index_capacity;
        }
        rlDisableVertexArray();
    }

    """Add a per-instance vertex buffer of `capacity` records, `stride` bytes
    each, described by `attributes` (their divisor is set to 1)."""
    def upload_instances(
        capacity: int, stride: int, attributes: list[VertexAttribute]
    ) {
        rlEnableVertexArray(u32(self.vao));
        self.instances = int(rlLoadVertexBuffer(bytes(capacity * stride), i32(capacity * stride), True));
        self.instance_capacity = capacity;
        for attribute in attributes {
            rlSetVertexAttribute(
                u32(attribute.location),
                i32(attribute.components),
                i32(attribute.kind),
                attribute.normalized,
                i32(stride),
                i32(attribute.offset)
            );
            rlEnableVertexAttribute(u32(attribute.location));
            rlSetVertexAttributeDivisor(u32(attribute.location), i32(1));
        }
        rlDisableVertexArray();
    }

    """Replace the first indices of the dynamic index buffer."""
    def set_indices(indices: bytes) {
        if self.ibo == 0 or not indices {
            return;
        }
        rlUpdateVertexBufferElements(u32(self.ibo), indices, i32(len(indices)), i32(0));
    }

    """Replace vertex data from `offset` bytes."""
    def set_vertices(data: bytes, offset: int = 0) {
        if data {
            rlUpdateVertexBuffer(u32(self.vbo), data, i32(len(data)), i32(offset));
        }
    }

    """Replace the first instance records, or from byte `offset` on."""
    def set_instances(data: bytes, offset: int = 0) {
        if self.instances != 0 and data {
            rlUpdateVertexBuffer(u32(self.instances), data, i32(len(data)), i32(offset));
        }
    }

    def bind() {
        rlEnableVertexArray(u32(self.vao));
    }

    def unbind() {
        rlDisableVertexArray();
    }

    """Draw `count` indices from index `first` (the mesh must be bound)."""
    def draw_indices(first: int, count: int) {
        if count > 0 {
            rlDrawVertexArrayElements(i32(first), i32(count), u64(0));
        }
    }

    """Draw `count` vertices from vertex `first` as triangles (bound)."""
    def draw_vertices(first: int, count: int) {
        if count > 0 {
            rlDrawVertexArray(i32(first), i32(count));
        }
    }

    """Draw `count` vertices `instances` times (bound)."""
    def draw_instances(first: int, count: int, instances: int) {
        if count > 0 and instances > 0 {
            rlDrawVertexArrayInstanced(i32(first), i32(count), i32(instances));
        }
    }

    def close() {
        if self.vao != 0 {
            rlUnloadVertexArray(u32(self.vao));
        }
        for buffer in [self.vbo, self.ibo, self.instances] {
            if buffer != 0 {
                rlUnloadVertexBuffer(u32(buffer));
            }
        }
        self.vao = 0;
        self.vbo = 0;
        self.ibo = 0;
        self.instances = 0;
    }
}

"""A linked shader program and its uniform locations, looked up by name
once and cached."""
obj GpuProgram {
    has id: int = 0,
        locations: dict[str, int] = {};

    """Compile and link `vertex` and `fragment` GLSL."""
    def load(vertex: str, fragment: str) {
        self.id = int(rlLoadShaderProgram(vertex, fragment));
        if self.id == 0 {
            raise RuntimeError("GPU shader failed to compile or link");
        }
        self.locations = {};
    }

    def uniform(name: str) -> int {
        if name not in self.locations {
            self.locations[name] = int(rlGetLocationUniform(u32(self.id), name));
        }
        return self.locations[name];
    }

    def attribute(name: str) -> int {
        return int(rlGetLocationAttrib(u32(self.id), name));
    }

    """Make the program current; raylib's batch is flushed first so its
    queued draws keep their order."""
    def begin() {
        rlDrawRenderBatchActive();
        rlEnableShader(u32(self.id));
    }

    def end() {
        rlDisableShader();
    }

    def set_matrix(name: str, value: Matrix) {
        location = self.uniform(name);
        if location >= 0 {
            rlSetUniformMatrix(i32(location), value);
        }
    }

    def set_float(name: str, value: float) {
        location = self.uniform(name);
        if location >= 0 {
            rlSetUniform(i32(location), struct.pack("<f", value), i32(UNIFORM_FLOAT), i32(1));
        }
    }

    def set_int(name: str, value: int) {
        location = self.uniform(name);
        if location >= 0 {
            rlSetUniform(i32(location), struct.pack("<i", value), i32(UNIFORM_INT), i32(1));
        }
    }

    """Set a vec4 array (or one vec4) from packed little-endian floats."""
    def set_vec4s(name: str, packed: bytes) {
        location = self.uniform(name);
        if location >= 0 and packed {
            rlSetUniform(i32(location), packed, i32(UNIFORM_VEC4), i32(len(packed) // 16));
        }
    }

    """Set a float array from packed little-endian floats."""
    def set_floats(name: str, packed: bytes) {
        location = self.uniform(name);
        if location >= 0 and packed {
            rlSetUniform(i32(location), packed, i32(UNIFORM_FLOAT), i32(len(packed) // 4));
        }
    }

    """Bind `texture` to `slot` and point sampler `name` at that slot."""
    def set_texture(name: str, slot: int, texture: int) {
        rlActiveTextureSlot(i32(slot));
        rlEnableTexture(u32(texture));
        self.set_int(name, slot);
    }

    def close() {
        if self.id != 0 {
            rlUnloadShaderProgram(u32(self.id));
            self.id = 0;
        }
    }
}

"""The current view-projection matrix (rlgl's modelview times projection),
for shaders that draw GPU meshes inside BeginMode3D."""
def view_projection -> Matrix {
    return MatrixMultiply(rlGetMatrixModelview(), rlGetMatrixProjection());
}

"""Upload `texels` (RGBA 32-bit floats, `width` x `height`) for texelFetch:
nearest sampling, no mipmaps."""
def upload_float_texture(texels: bytes, width: int, height: int) -> int {
    id = int(rlLoadTexture(texels, i32(width), i32(height), i32(PIXEL_RGBA32F), i32(1)));
    if id == 0 {
        raise RuntimeError("Float texture upload failed");
    }
    rlTextureParameters(u32(id), i32(10241), i32(9728));
    rlTextureParameters(u32(id), i32(10240), i32(9728));
    return id;
}

"""Pack floats as little-endian 32-bit values."""
def pack_floats(values: list[float]) -> bytes {
    out = bytearray(len(values) * 4);
    for i in range(len(values)) {
        struct.pack_into("<f", out, i * 4, values[i]);
    }
    return bytes(out);
}

"""Pack ints as little-endian unsigned 16-bit indices."""
def pack_indices(values: list[int]) -> bytes {
    out = bytearray(len(values) * 2);
    for i in range(len(values)) {
        struct.pack_into("<H", out, i * 2, values[i]);
    }
    return bytes(out);
}
