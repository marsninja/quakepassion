"""A model being edited, as a graph: the model, its parts (each a mesh of
its own, with its own skins), each part's poses (where its points stand at
each frame) and its tags (places other models are hung from).

A part's triangles and its places on the skin are the same at every frame;
only the points move. So a tool that moves points works on one pose or on
all of them, and a tool that changes the triangles is carried to every pose
by a walker, which leaves each pose with the same points in the same order."""
import from engine.math.vec3 { Vec3 }
import from .mesh {
    Mesh,
    mesh_moved,
    mesh_turned,
    mesh_scaled,
    mesh_mirrored,
    mesh_flipped,
    mesh_subdivided,
    mesh_extruded,
    mesh_faults,
    points_of_faces,
    faces_of_points,
    faces_toward
}

"""A model has its parts, in order."""
edge HasPart: ModelDoc --> Part {
    has index: int = 0;
}

"""A part has a pose for each frame, in order."""
edge HasPose: Part --> Pose {
    has index: int = 0;
}

edge HasTag: ModelDoc --> Tag {}

"""Where a part's points stand at one frame."""
node Pose {
    has name: str = "",
        points: list[Vec3] = [];
}

"""A part of a model: a mesh with skins of its own, and what of it is picked."""
node Part {
    has name: str = "part",
        corners: list[int] = [],
        uvs: list[float] = [],
        skins: list[str] = [],
        picked_points: list[int] = [],
        picked_faces: list[int] = [];
}

"""A place on a model that another is hung from: where it is at each frame,
and how it is turned (three axes a frame)."""
node Tag {
    has name: str,
        origins: list[Vec3] = [],
        axes: list[list[Vec3]] = [];
}

"""A part as it was, whole: what an edit is undone to."""
obj PartState {
    has corners: list[int] = [],
        uvs: list[float] = [],
        poses: list[list[Vec3]] = [],
        picked_points: list[int] = [],
        picked_faces: list[int] = [];
}

"""One edit of one part: how it stood before and after."""
obj ModelStep {
    has label: str,
        part: Part,
        before: PartState,
        after: PartState;
}

"""Carry a tool to every pose of a part (or to one). The walker starts on
the part, visits its poses in turn and leaves each with its points as the
tool left them; the triangles and the skin the tool made are the same for
every pose and are left on the walker for the part to take."""
walker Reshape {
    has kind: str,
        faces: list[int] = [],
        picks: list[int] = [],
        vector: Vec3 = Vec3(),
        pivot: Vec3 = Vec3(),
        axis: int = 2,
        amount: float = 0.0,
        count: int = 0,
        bulk: bool = False,
        # The one frame to work on (every frame when below zero).
        only: int = -1,
        # The pose that says where things are, for tools that measure.
        guide: Mesh | None = None,
        corners: list[int] = [],
        uvs: list[float] = [],
        made_corners: list[int] = [],
        made_uvs: list[float] = [],
        touched: int = 0;

    can start with Part entry {
        self.corners = list(here.corners);
        self.uvs = list(here.uvs);
        self.made_corners = list(here.corners);
        self.made_uvs = list(here.uvs);
        visit [here->:HasPose:->];
    }

    can shape with Pose entry {
        if self.only >= 0 and self.only != self.touched {
            # Another frame than the one asked for: left as it is. (A tool
            # that changes the triangles is never asked for one frame.)
            self.touched += 1;
            return;
        }
        self.touched += 1;
        mesh = Mesh(points=here.points, corners=self.corners, uvs=self.uvs);
        made = mesh;
        if self.kind == "move" {
            made = mesh_moved(mesh, self.picks, self.vector);
        } elif self.kind == "turn" {
            made = mesh_turned(mesh, self.picks, self.pivot, self.axis, self.amount);
        } elif self.kind == "scale" {
            made = mesh_scaled(mesh, self.picks, self.pivot, self.vector);
        } elif self.kind == "mirror" {
            made = mesh_mirrored(mesh, self.axis, self.amount);
        } elif self.kind == "flip" {
            made = mesh_flipped(mesh, self.faces);
        } elif self.kind == "subdivide" {
            made = mesh_subdivided(mesh, self.faces, self.count, self.guide);
        } elif self.kind == "extrude" {
            made = mesh_extruded(mesh, self.faces, self.amount, self.bulk);
        }
        here.points = made.points;
        self.made_corners = made.corners;
        self.made_uvs = made.uvs;
    }
}

"""The model: what it is called, which frame and part are in hand, and the
edits made, to undo."""
node ModelDoc {
    has name: str = "model",
        frame: int = 0,
        part_now: int = 0,
        dirty: bool = False,
        revision: int = 0,
        done: list[ModelStep] = [],
        undone: list[ModelStep] = [],
        limit: int = 24;

    def parts -> list[Part] {
        return [self->:HasPart:->][?:Part];
    }

    def tags -> list[Tag] {
        return [self->:HasTag:->][?:Tag];
    }

    def poses(part: Part) -> list[Pose] {
        return [part->:HasPose:->][?:Pose];
    }

    """How many frames the model has: its first part's."""
    def frames -> int {
        held = self.parts();
        return len(self.poses(held[0])) if len(held) > 0 else 0;
    }

    """The part in hand, or none when the model has no parts."""
    def part -> Part | None {
        held = self.parts();
        if len(held) == 0 {
            return None;
        }
        return held[max(0, min(self.part_now, len(held) - 1))];
    }

    """A part's mesh at a frame (the frame in hand when below zero)."""
    def mesh(part: Part, frame: int = -1) -> Mesh {
        stood = self.poses(part);
        if len(stood) == 0 {
            return Mesh(corners=list(part.corners), uvs=list(part.uvs));
        }
        at = self.frame if frame < 0 else frame;
        return Mesh(points=list(stood[max(0, min(at, len(stood) - 1))].points), corners=list(part.corners), uvs=list(part.uvs));
    }

    """Add a part from a mesh: it stands the same at every frame the model
    has (one, when this is its first part)."""
    def add_part(name: str, mesh: Mesh, skins: list[str] = []) -> Part {
        count = max(1, self.frames());
        names = [pose.name for pose in self.poses(self.parts()[0])] if len(self.parts()) > 0 else ["frame 0"];
        part = Part(name=name, corners=list(mesh.corners), uvs=list(mesh.uvs), skins=list(skins));
        self +>:HasPart(index=len(self.parts())):+> part;
        for index in range(count) {
            part +>:HasPose(index=index):+> Pose(name=names[index] if index < len(names) else "frame " + str(index), points=list(mesh.points));
        }
        self.part_now = len(self.parts()) - 1;
        self.dirty = True;
        self.revision += 1;
        return part;
    }

    """A part as it stands, whole."""
    def state(part: Part) -> PartState {
        return PartState(
            corners=list(part.corners),
            uvs=list(part.uvs),
            poses=[list(pose.points) for pose in self.poses(part)],
            picked_points=list(part.picked_points),
            picked_faces=list(part.picked_faces)
        );
    }

    def restore(part: Part, kept: PartState) {
        part.corners = list(kept.corners);
        part.uvs = list(kept.uvs);
        part.picked_points = list(kept.picked_points);
        part.picked_faces = list(kept.picked_faces);
        for (index, pose) in enumerate(self.poses(part)) {
            if index < len(kept.poses) {
                pose.points = list(kept.poses[index]);
            }
        }
        self.dirty = True;
        self.revision += 1;
    }

    """Carry a tool to the part in hand and remember how it stood before.
    False when there is no part, or the tool changed nothing."""
    def reshape(tool: Reshape, label: str) -> bool {
        part = self.part();
        if part is None {
            return False;
        }
        before = self.state(part);
        tool.guide = self.mesh(part);
        part spawn tool;
        part.corners = tool.made_corners;
        part.uvs = tool.made_uvs;
        after = self.state(part);
        if after.corners == before.corners and after.poses == before.poses {
            return False;
        }
        if after.corners != before.corners {
            # The triangles are others now: what was picked by number is
            # not what those numbers mean any more.
            part.picked_points = [];
            part.picked_faces = [];
            after = self.state(part);
        }
        self.done.append(ModelStep(label=label, part=part, before=before, after=after));
        if len(self.done) > self.limit {
            self.done = self.done[1:];
        }
        self.undone = [];
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    """Undo the last edit. Answers what it was called ("" when there is none)."""
    def undo -> str {
        if len(self.done) == 0 {
            return "";
        }
        step = self.done.pop();
        self.restore(step.part, step.before);
        self.undone.append(step);
        return step.label;
    }

    def redo -> str {
        if len(self.undone) == 0 {
            return "";
        }
        step = self.undone.pop();
        self.restore(step.part, step.after);
        self.done.append(step);
        return step.label;
    }

    # ------------------------------------------------------------------
    # What is picked

    """Pick points of the part in hand: those numbered, alone or added."""
    def pick_points(picks: list[int], add: bool = False) -> int {
        part = self.part();
        if part is None {
            return 0;
        }
        count = len(self.mesh(part).points);
        chosen = list(part.picked_points) if add else [];
        for index in picks {
            if index >= 0 and index < count and index not in chosen {
                chosen.append(index);
            }
        }
        part.picked_points = sorted(chosen);
        self.revision += 1;
        return len(part.picked_points);
    }

    """Pick triangles of the part in hand, and with them their points."""
    def pick_faces(faces: list[int], add: bool = False) -> int {
        part = self.part();
        if part is None {
            return 0;
        }
        count = len(part.corners) // 3;
        chosen = list(part.picked_faces) if add else [];
        for index in faces {
            if index >= 0 and index < count and index not in chosen {
                chosen.append(index);
            }
        }
        part.picked_faces = sorted(chosen);
        part.picked_points = points_of_faces(self.mesh(part), part.picked_faces);
        self.revision += 1;
        return len(part.picked_faces);
    }

    """Pick the triangles that face toward where one looks from, or away."""
    def pick_facing(sight: Vec3, front: bool = True) -> int {
        part = self.part();
        if part is None {
            return 0;
        }
        return self.pick_faces(faces_toward(self.mesh(part), sight, front));
    }

    """The middle of what is picked (of the whole part when nothing is)."""
    def picked_middle -> Vec3 {
        part = self.part();
        if part is None {
            return Vec3();
        }
        mesh = self.mesh(part);
        picks = part.picked_points if len(part.picked_points) > 0 else list(range(len(mesh.points)));
        if len(picks) == 0 {
            return Vec3();
        }
        total = Vec3();
        for index in picks {
            total = total.add(mesh.points[index]);
        }
        return total.scale(1.0 / float(len(picks)));
    }

    # ------------------------------------------------------------------
    # The whole model

    """The box round every part at a frame: [low, high]."""
    def bounds(frame: int = -1) -> list[Vec3] {
        far = 1000000.0;
        low = Vec3(x=far, y=far, z=far);
        high = Vec3(x=-far, y=-far, z=-far);
        for part in self.parts() {
            for point in self.mesh(part, frame).points {
                low = Vec3(x=min(low.x, point.x), y=min(low.y, point.y), z=min(low.z, point.z));
                high = Vec3(x=max(high.x, point.x), y=max(high.y, point.y), z=max(high.z, point.z));
            }
        }
        return [low, high] if low.x <= high.x else [Vec3(), Vec3()];
    }

    """What is wrong with the model: each part's mesh faults, and parts
    that do not have the frames the first has."""
    def faults -> list[str] {
        found: list[str] = [];
        count = self.frames();
        for part in self.parts() {
            for fault in mesh_faults(self.mesh(part, 0)) {
                found.append(part.name + ": " + fault);
            }
            stood = self.poses(part);
            if len(stood) != count {
                found.append(part.name + " has " + str(len(stood)) + " frames, the model " + str(count));
            }
            for pose in stood {
                if len(pose.points) != len(stood[0].points) {
                    found.append(part.name + ": frame " + pose.name + " has other points than the first");
                    break;
                }
            }
        }
        return found;
    }

    """Give every part the frames the first has: missing ones are copies of
    its last, and ones too many are dropped. Answers how many parts changed."""
    def match_frames -> int {
        count = self.frames();
        changed = 0;
        for part in self.parts() {
            stood = self.poses(part);
            if len(stood) == count or len(stood) == 0 {
                continue;
            }
            for index in range(len(stood), count) {
                part +>:HasPose(index=index):+> Pose(name="frame " + str(index), points=list(stood[-1].points));
            }
            for pose in stood[count:] {
                part del->:HasPose:-> pose;
            }
            changed += 1;
        }
        if changed > 0 {
            self.dirty = True;
            self.revision += 1;
        }
        return changed;
    }

    # ------------------------------------------------------------------
    # Frames

    """Add a frame after one, a copy of it in every part. Answers its number."""
    def copy_frame(frame: int, name: str = "") -> int {
        count = self.frames();
        if frame < 0 or frame >= count {
            return -1;
        }
        for part in self.parts() {
            stood = self.poses(part);
            fresh = Pose(name=name if name else stood[frame].name + " copy", points=list(stood[frame].points));
            # The poses are kept in order by taking them all off and
            # putting them back with the new one in its place.
            order = stood[:frame + 1] + [fresh] + stood[frame + 1:];
            for pose in stood {
                part del->:HasPose:-> pose;
            }
            for (index, pose) in enumerate(order) {
                part +>:HasPose(index=index):+> pose;
            }
        }
        self.frame = frame + 1;
        self.dirty = True;
        self.revision += 1;
        return frame + 1;
    }

    """Take a frame out of every part. A model keeps one frame at least."""
    def drop_frame(frame: int) -> bool {
        count = self.frames();
        if count <= 1 or frame < 0 or frame >= count {
            return False;
        }
        for part in self.parts() {
            stood = self.poses(part);
            if frame < len(stood) {
                part del->:HasPose:-> stood[frame];
            }
        }
        self.frame = max(0, min(self.frame, count - 2));
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    def name_frame(frame: int, name: str) -> bool {
        if frame < 0 or frame >= self.frames() or not name {
            return False;
        }
        for part in self.parts() {
            stood = self.poses(part);
            if frame < len(stood) {
                stood[frame].name = name;
            }
        }
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    def frame_name(frame: int) -> str {
        held = self.parts();
        if len(held) == 0 {
            return "";
        }
        stood = self.poses(held[0]);
        return stood[frame].name if frame >= 0 and frame < len(stood) else "";
    }
}
