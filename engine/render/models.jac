"""One renderer for adapted vertex-animated models, with explicit GPU ownership."""
import math;
import from ..formats.animated { AnimatedModel, ModelStage, pose }
import from ..formats.bsp { Texture }
import from ..math.vec3 { Vec3 }
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
    rlEnableDepthMask
}
import from vendor.raylib {
    def rlSetBlendFactors(src: i32, dst: i32, equation: i32) -> None;
}

obj UploadedStage {
    has texture: int,
        surface: int,
        environment: bool,
        scroll_u: float,
        scroll_v: float,
        blend: str;
}

obj ModelRenderer {
    has model: AnimatedModel = AnimatedModel(),
        textures: list[int] = [],
        stages: list[UploadedStage] = [];

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
                    self.stages.append(
                        UploadedStage(
                            texture=texture,
                            surface=s,
                            environment=stage.environment,
                            scroll_u=stage.scroll_u,
                            scroll_v=stage.scroll_v,
                            blend=stage.blend
                        )
                    );
                }
            }
            self.model = model;
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
        seconds: float = 0.0
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
        for s in range(len(self.model.surfaces)) {
            surface = self.model.surfaces[s];
            vertices = pose(surface, first, second, blend);
            for stage in self.stages {
                if stage.surface != s {
                    continue;
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
                rlSetTexture(u32(stage.texture));
                rlBegin(i32(4));
                rlColor4ub(u8(255), u8(255), u8(255), u8(255));
                for triangle in range(len(surface.indices) // 3) {
                    # Alias model file triangles wind clockwise; rlgl expects CCW.
                    for corner in [0, 2, 1] {
                        index = triangle * 3 + corner;
                        v = vertices[surface.indices[index]];
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
                        rlVertex3f(
                            f32(origin.x + v.x * cosine - v.y * sine),
                            f32(origin.y + v.x * sine + v.y * cosine),
                            f32(origin.z + v.z)
                        );
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

    def draw(world: World, eye: Vec3 = Vec3(), seconds: float = 0.0) {
        scene = world spawn GatherModels();
        for draw in scene.draws {
            if draw.resource.name in self.resources {
                self.resources[draw.resource.name].draw(
                    draw.origin,
                    draw.yaw,
                    draw.first,
                    draw.second,
                    draw.blend,
                    eye,
                    seconds
                );
            }
        }
    }

    def close() {
        for name in self.resources.keys() {
            self.resources[name].close();
        }
        self.resources = {};
    }
}
