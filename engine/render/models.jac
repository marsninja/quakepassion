"""One renderer for adapted vertex-animated models, with explicit GPU ownership."""
import math;
import from ..math.orientation { Basis, model_basis }
import from ..formats.animated { AnimatedModel, ModelStage, pose, stage_frame }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3, forward_from, right_from }
import from ..world.lighting { Lighting, Illumination }
import from .quake {
    QuakeRenderer,
    rlLoadTexture,
    rlUnloadTexture,
    rlSetTexture,
    rlBegin,
    rlEnd,
    rlTexCoord2f,
    rlVertex3f,
    rlColor4ub,
    rlDrawRenderBatchActive,
    BeginBlendMode,
    EndBlendMode,
    rlDisableDepthMask,
    rlEnableDepthMask,
    rlDisableBackfaceCulling,
    rlEnableBackfaceCulling,
    fog_coords
}
import from ..formats.bsp { FogVolume }
import from vendor.raylib {
    def rlSetBlendFactors(src: i32, dst: i32, equation: i32) -> None;
}

obj UploadedStage {
    has texture: int,
        surface: int,
        environment: bool,
        scroll_u: float,
        scroll_v: float,
        blend: str,
        two_sided: bool = False,
        frames: list[int] = [],
        frequency: float = 0.0;
}

obj ModelRenderer {
    has model: AnimatedModel = AnimatedModel(),
        textures: list[int] = [],
        stages: list[UploadedStage] = [],
        radius: float = 0.0;

    def upload(model: AnimatedModel, skins: list[Texture]) {
        self.close();
        if len(skins) != len(model.surfaces) {
            raise ValueError("Every model surface needs a skin");
        }
        try {
            for s in range(len(skins)) {
                stages = model.surfaces[s].stages;
                if not stages {
                    stages = [ModelStage(texture=skins[s])];
                }
                for stage in stages {
                    skin = stage.texture;
                    uploaded: list[int] = [];
                    for skin in (stage.frames if stage.frames else [stage.texture]) {
                        texture = 0;
                        if skin.encoded {
                            texture = QuakeRenderer().upload_image(skin);
                        } elif len(skin.pixels) != skin.width * skin.height * 4 {
                            raise ValueError("Model skin must be RGBA");
                        } else {
                            texture = int(
                                rlLoadTexture(
                                    skin.pixels,
                                    i32(skin.width),
                                    i32(skin.height),
                                    i32(7),
                                    i32(1)
                                )
                            );
                        }
                        if texture == 0 {
                            raise RuntimeError("Model skin upload failed");
                        }
                        self.textures.append(texture);
                        uploaded.append(texture);
                    }
                    self.stages.append(
                        UploadedStage(
                            texture=uploaded[0],
                            frames=uploaded,
                            frequency=stage.frequency,
                            surface=s,
                            environment=stage.environment,
                            scroll_u=stage.scroll_u,
                            scroll_v=stage.scroll_v,
                            blend=stage.blend,
                            two_sided=skin.two_sided
                        )
                    );
                }
            }
            self.model = model;
            self.radius = 0.0;
            for surface in model.surfaces {
                for frame in surface.frames {
                    for vertex in frame.vertices {
                        self.radius = max(self.radius, vertex.length());
                    }
                }
            }
        } except Exception {
            self.close();
            raise;
        }
    }

    def draw(
        origin: Vec3,
        yaw: float,
        first: int = 0,
        second: int = 0,
        blend: float = 0.0,
        eye: Vec3 = Vec3(),
        seconds: float = 0.0,
        batched: bool = False,
        illumination: Illumination = Illumination(),
        basis: Basis | None = None,
        fog: FogVolume | None = None,
        fog_image: int = 0,
        forward: Vec3 = Vec3(x=1.0)
    ) {
        if not self.stages {
            return;
        }
        cosine = math.cos(yaw);
        sine = math.sin(yaw);
        view = eye.sub(origin);
        local_eye = Vec3(
            x=view.x * cosine + view.y * sine,
            y=-view.x * sine + view.y * cosine,
            z=view.z
        );
        if basis is not None {
            local_eye = basis.inverse(view);
        }
        for s in range(len(self.model.surfaces)) {
            surface = self.model.surfaces[s];
            vertices = pose(surface, first, second, blend);
            colors: list[Vec3] = [];
            if illumination.enabled {
                normals = surface.frames[first].normals;
                next_normals = surface.frames[second].normals;
                for vertex in range(len(vertices)) {
                    color = illumination.ambient.add(illumination.directed.scale(0.5));
                    if len(normals) == len(vertices)
                        and len(next_normals) == len(vertices) {
                        n = normals[vertex].lerp(
                            next_normals[vertex], max(0.0, min(1.0, blend))
                        ).normalized();
                        normal = Vec3(
                            x=n.x * cosine - n.y * sine,
                            y=n.x * sine + n.y * cosine,
                            z=n.z
                        );
                        if basis is not None {
                            normal = basis.apply(n);
                        }
                        color = illumination.shade(normal);
                    }
                    colors.append(color);
                }
            }
            for stage in self.stages {
                if stage.surface != s {
                    continue;
                }
                if stage.two_sided {
                    rlDrawRenderBatchActive();
                    rlDisableBackfaceCulling();
                }
                if stage.blend == "opaque" {
                    rlSetBlendFactors(i32(1), i32(0), i32(32774));
                    BeginBlendMode(i32(6));
                } else {
                    BeginBlendMode(
                        i32(
                            1
                                if stage.blend == "add"
                                else (2 if stage.blend == "multiply" else 0)
                        )
                    );
                    rlDrawRenderBatchActive();
                    rlDisableDepthMask();
                }
                rlSetTexture(
                    u32(
                        stage.frames[
                            stage_frame(seconds, stage.frequency, len(stage.frames))
                        ]
                    )
                );
                rlBegin(i32(4));
                rlColor4ub(u8(255), u8(255), u8(255), u8(255));
                for triangle in range(len(surface.indices) // 3) {
                    # Alias model file triangles wind clockwise; rlgl expects CCW.
                    for corner in [0, 2, 1] {
                        index = triangle * 3 + corner;
                        v = vertices[surface.indices[index]];
                        if illumination.enabled and stage.blend == "opaque" {
                            color = colors[surface.indices[index]];
                            rlColor4ub(
                                u8(int(min(255.0, max(0.0, color.x * 255.0)))),
                                u8(int(min(255.0, max(0.0, color.y * 255.0)))),
                                u8(int(min(255.0, max(0.0, color.z * 255.0)))),
                                u8(255)
                            );
                        }
                        u = surface.uv[index * 2];
                        t = surface.uv[index * 2 + 1];
                        if stage.environment {
                            vertex = surface.indices[index];
                            a = surface.frames[first].normals;
                            b = surface.frames[second].normals;
                            if len(a) != len(vertices) or len(b) != len(vertices) {
                                raise ValueError(
                                    "Environment mapping needs model normals"
                                );
                            }
                            normal = a[vertex].lerp(
                                b[vertex], max(0.0, min(1.0, blend))
                            ).normalized();
                            viewer = local_eye.sub(v).normalized();
                            reflection = normal.scale(2.0 * normal.dot(viewer)).sub(
                                viewer
                            );
                            u = 0.5 + reflection.y * 0.5;
                            t = 0.5 - reflection.z * 0.5;
                        }
                        rlTexCoord2f(
                            f32(u + seconds * stage.scroll_u),
                            f32(t + seconds * stage.scroll_v)
                        );
                        if basis is not None {
                            point = origin.add(basis.apply(v));
                            rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
                        } else {
                            rlVertex3f(
                                f32(origin.x + v.x * cosine - v.y * sine),
                                f32(origin.y + v.x * sine + v.y * cosine),
                                f32(origin.z + v.z)
                            );
                        }
                    }
                }
                rlEnd();
                if stage.two_sided {
                    rlDrawRenderBatchActive();
                    rlEnableBackfaceCulling();
                }
                if stage.blend != "opaque" {
                    rlDrawRenderBatchActive();
                    rlEnableDepthMask();
                    EndBlendMode();
                } elif not batched {
                    EndBlendMode();
                }
            }
            # RB_FogPass over the model's opaque surfaces inside a fog volume.
            if fog is not None and fog_image != 0 and any([stage.surface == s and stage.blend == "opaque" for stage in self.stages]) {
                rlDrawRenderBatchActive();
                BeginBlendMode(i32(0));
                rlDisableDepthMask();
                rlSetTexture(u32(fog_image));
                rlBegin(i32(4));
                rlColor4ub(
                    u8(min(255, int(fog.color.x * 255.0))),
                    u8(min(255, int(fog.color.y * 255.0))),
                    u8(min(255, int(fog.color.z * 255.0))),
                    u8(255)
                );
                for triangle in range(len(surface.indices) // 3) {
                    for corner in [0, 2, 1] {
                        v = vertices[surface.indices[triangle * 3 + corner]];
                        point = origin.add(basis.apply(v)) if basis is not None else Vec3(
                            x=origin.x + v.x * cosine - v.y * sine,
                            y=origin.y + v.x * sine + v.y * cosine,
                            z=origin.z + v.z
                        );
                        st = fog_coords(fog, point, eye, forward);
                        rlTexCoord2f(f32(st[0]), f32(st[1]));
                        rlVertex3f(f32(point.x), f32(point.y), f32(point.z));
                    }
                }
                rlEnd();
                rlDrawRenderBatchActive();
                rlEnableDepthMask();
                EndBlendMode();
            }
        }
        rlSetTexture(u32(0));
    }

    def close() {
        if self.textures {
            rlDrawRenderBatchActive();
        }
        for texture in self.textures {
            rlUnloadTexture(u32(texture));
        }
        self.textures = [];
        self.stages = [];
        self.model = AnimatedModel();
    }
}

import from ..world.world { World }
import from ..world.models { ModelResource, HasModelResource, GatherModels }

"""tr_main.c R_ComputeFogNum: the first fog volume the model's bounding sphere
overlaps."""
def model_fog(fogs: list[FogVolume], origin: Vec3, radius: float) -> FogVolume | None {
    for fog in fogs {
        if origin.x - radius < fog.maxs.x and origin.x + radius > fog.mins.x
            and origin.y - radius < fog.maxs.y and origin.y + radius > fog.mins.y
            and origin.z - radius < fog.maxs.z and origin.z + radius > fog.mins.z {
            return fog;
        }
    }
    return None;
}

obj ModelScene {
    has resources: dict[str, ModelRenderer] = {};

    def upload(world: World) {
        self.close();
        try {
            for resource in [world->:HasModelResource:->][?:ModelResource] {
                if resource.name in self.resources {
                    continue;
                }
                drawing = ModelRenderer();
                drawing.upload(resource.model, resource.skins);
                self.resources[resource.name] = drawing;
            }
        } except Exception {
            self.close();
            raise;
        }
    }

    def draw(
        world: World,
        eye: Vec3 = Vec3(),
        seconds: float = 0.0,
        culling: bool = False,
        yaw: float = 0.0,
        pitch: float = 0.0,
        fov: float = 72.0,
        aspect: float = 1.7777777778,
        lighting: Lighting = Lighting(),
        fogs: list[FogVolume] = [],
        fog_image: int = 0
    ) {
        scene = world spawn GatherModels(seconds=seconds);
        forward = forward_from(yaw, pitch);
        for draw in scene.draws {
            if draw.resource.name in self.resources {
                renderer = self.resources[draw.resource.name];
                if culling
                    and not sphere_in_view(
                        draw.origin.sub(eye), renderer.radius, yaw, pitch, fov, aspect
                    ) {
                    continue;
                }
                renderer.draw(
                    draw.origin,
                    draw.yaw,
                    draw.first,
                    draw.second,
                    draw.blend,
                    eye,
                    seconds,
                    batched=True,
                    illumination=lighting.sample(draw.origin.add(Vec3(z=16.0))),
                    basis=model_basis(draw.yaw, draw.pitch, draw.roll)
                        if draw.pitch != 0.0 or draw.roll != 0.0
                        else None,
                    fog=model_fog(fogs, draw.origin, renderer.radius),
                    fog_image=fog_image,
                    forward=forward
                );
            }
        }
        EndBlendMode();
    }

    def close() {
        for name in self.resources.keys() {
            self.resources[name].close();
        }
        self.resources = {};
    }
}

def sphere_in_view(
    delta: Vec3, radius: float, yaw: float, pitch: float, fov: float, aspect: float
) -> bool {
    forward = forward_from(yaw, pitch);
    right = right_from(yaw);
    up = right.cross(forward);
    depth = delta.dot(forward);
    vertical = math.tan(fov * math.pi / 360.0);
    horizontal = vertical * aspect;
    return depth >= -radius
        and abs(delta.dot(right))
            <= depth * horizontal + radius * math.sqrt(1.0 + horizontal * horizontal)
        and abs(delta.dot(up))
            <= depth * vertical + radius * math.sqrt(1.0 + vertical * vertical);
}
