"""A model being edited, as a graph: the model, its parts (each a mesh of
its own, with its own skins), each part's poses (where its points stand at
each frame) and its tags (places other models are hung from). A model may
have bones as well: each jointed to those that hang from it, each with a
grip on the points it carries of each part, to pose the model by.

A part's triangles and its places on the skin are the same at every frame;
only the points move. So a tool that moves points works on one pose or on
all of them, and a tool that changes the triangles is carried to every pose
by a walker, which leaves each pose with the same points in the same order."""
import math;
import from engine.math.vec3 { Vec3 }
import from .mesh {
    Mesh,
    mesh_moved,
    mesh_turned,
    mesh_scaled,
    mesh_mirrored,
    mesh_flipped,
    mesh_subdivided,
    mesh_cut,
    mesh_extruded,
    mesh_faults,
    points_of_faces,
    faces_of_points,
    faces_toward
}
import from .bones {
    points_swung,
    points_carried,
    point_swung,
    grip_with,
    grip_without,
    grip_share,
    shares_beside,
    nearest_bones,
    frames_spread,
    tint_mixed,
    BONE_TINTS
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

"""A model has its bones."""
edge HasBone: ModelDoc --> Bone {}

"""A bone is jointed to each bone that hangs from it."""
edge Jointed: Bone --> Bone {}

"""A bone has a grip on each part it carries points of."""
edge Holds: Bone --> Grip {}

edge GripOf: Grip --> Part {}

"""A bone: where its joint is and where it reaches to, at each frame, and
the colour it and what it carries are shown in."""
node Bone {
    has name: str,
        heads: list[Vec3] = [],
        tails: list[Vec3] = [],
        tint: int = 0xffc94d;
}

"""What a bone carries of one part: points by number, and how much of each
(from nothing to all of it)."""
node Grip {
    has points: list[int] = [],
        weights: list[float] = [];
}

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

"""A bone's ends as they were, at every frame."""
obj BoneState {
    has bone: Bone,
        heads: list[Vec3] = [],
        tails: list[Vec3] = [];
}

"""One edit of one part: how it stood before and after. A pose made with
bones changes more than one part, and the bones: the other parts as steps
of their own in `rest`, and the bones as they stood."""
obj ModelStep {
    has label: str,
        part: Part,
        before: PartState,
        after: PartState,
        rest: list[ModelStep] = [],
        bones_before: list[BoneState] = [],
        bones_after: list[BoneState] = [];
}

"""Carry a turn or a move down a bone and all that hangs from it, at one
frame. The walker starts on the bone and takes its ends where they go, then
goes to each grip it has and on to the bones jointed to it, which go round
whole: ends and all. Of the points it does not move any itself: it gathers,
for each part it meets, how much of each point the bones it passed carry
between them, for the points to be moved once by that much."""
walker Swing {
    has frame: int,
        pivot: Vec3 = Vec3(),
        axis: Vec3 = Vec3(z=1.0),
        degrees: float = 0.0,
        delta: Vec3 = Vec3(),
        turning: bool = True,
        first: bool = True,
        carried: list[Part] = [],
        shares: list[list[float]] = [];

    can start with Bone entry {
        if self.frame < len(here.heads) and self.frame < len(here.tails) {
            if self.turning {
                # The bone asked for turns about its own joint, which stays;
                # one that hangs from it is taken round, joint and all.
                if not self.first {
                    here.heads[self.frame] = point_swung(here.heads[self.frame], self.pivot, self.axis, self.degrees);
                }
                here.tails[self.frame] = point_swung(here.tails[self.frame], self.pivot, self.axis, self.degrees);
            } else {
                here.heads[self.frame] = here.heads[self.frame].add(self.delta);
                here.tails[self.frame] = here.tails[self.frame].add(self.delta);
            }
        }
        self.first = False;
        visit [here->:Holds:->];
        visit [here->:Jointed:->];
    }

    can gather with Grip entry {
        for part in [here->:GripOf:->][?:Part] {
            place = -1;
            for (index, known) in enumerate(self.carried) {
                if known is part {
                    place = index;
                }
            }
            if place < 0 {
                stood = [part->:HasPose:->][?:Pose];
                self.carried.append(part);
                self.shares.append([0.0 for point in (stood[0].points if len(stood) > 0 else [])]);
                place = len(self.carried) - 1;
            }
            for (number, index) in enumerate(here.points) {
                if index >= 0 and index < len(self.shares[place]) {
                    share = here.weights[number] if number < len(here.weights) else 1.0;
                    self.shares[place][index] = min(1.0, self.shares[place][index] + share);
                }
            }
        }
    }
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
        } elif self.kind == "cut" {
            made = mesh_cut(mesh, self.faces, self.pivot, self.vector, self.guide);
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

    """Give the part in hand other places on its skin, as one edit. False
    when there are not two numbers for each of its points, or nothing changed."""
    def reskin(uvs: list[float], label: str) -> bool {
        part = self.part();
        if part is None {
            return False;
        }
        stood = self.poses(part);
        count = len(stood[0].points) if len(stood) > 0 else 0;
        if len(uvs) != count * 2 or uvs == part.uvs {
            return False;
        }
        before = self.state(part);
        part.uvs = list(uvs);
        self.done.append(ModelStep(label=label, part=part, before=before, after=self.state(part)));
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
        for more in step.rest {
            self.restore(more.part, more.before);
        }
        for kept in step.bones_before {
            kept.bone.heads = list(kept.heads);
            kept.bone.tails = list(kept.tails);
        }
        self.undone.append(step);
        return step.label;
    }

    def redo -> str {
        if len(self.undone) == 0 {
            return "";
        }
        step = self.undone.pop();
        self.restore(step.part, step.after);
        for more in step.rest {
            self.restore(more.part, more.after);
        }
        for kept in step.bones_after {
            kept.bone.heads = list(kept.heads);
            kept.bone.tails = list(kept.tails);
        }
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
        for tag in self.tags() {
            # A tag stands in the copy where it stood in what was copied.
            if frame < len(tag.origins) and frame < len(tag.axes) {
                tag.origins.insert(frame + 1, tag.origins[frame]);
                tag.axes.insert(frame + 1, list(tag.axes[frame]));
            }
        }
        for bone in self.bones() {
            if frame < len(bone.heads) and frame < len(bone.tails) {
                bone.heads.insert(frame + 1, bone.heads[frame]);
                bone.tails.insert(frame + 1, bone.tails[frame]);
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
        for tag in self.tags() {
            if frame < len(tag.origins) and frame < len(tag.axes) {
                tag.origins.pop(frame);
                tag.axes.pop(frame);
            }
        }
        for bone in self.bones() {
            if frame < len(bone.heads) and frame < len(bone.tails) {
                bone.heads.pop(frame);
                bone.tails.pop(frame);
            }
        }
        self.frame = max(0, min(self.frame, count - 2));
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    """Move a frame to another place in the order, in every part."""
    def move_frame(frame: int, to: int) -> bool {
        count = self.frames();
        if frame < 0 or frame >= count or to < 0 or to >= count or frame == to {
            return False;
        }
        for part in self.parts() {
            stood = self.poses(part);
            if frame >= len(stood) or to >= len(stood) {
                continue;
            }
            order = [pose for pose in stood if pose is not stood[frame]];
            order = order[:to] + [stood[frame]] + order[to:];
            for pose in stood {
                part del->:HasPose:-> pose;
            }
            for (index, pose) in enumerate(order) {
                part +>:HasPose(index=index):+> pose;
            }
        }
        for tag in self.tags() {
            if frame < len(tag.origins) and to < len(tag.origins) {
                moved_at = tag.origins.pop(frame);
                tag.origins.insert(to, moved_at);
                moved_axes = tag.axes.pop(frame);
                tag.axes.insert(to, moved_axes);
            }
        }
        for bone in self.bones() {
            if frame < len(bone.heads) and to < len(bone.heads) and len(bone.tails) == len(bone.heads) {
                moved_head = bone.heads.pop(frame);
                bone.heads.insert(to, moved_head);
                moved_tail = bone.tails.pop(frame);
                bone.tails.insert(to, moved_tail);
            }
        }
        self.frame = to;
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    # ------------------------------------------------------------------
    # Tags

    def tag(name: str) -> Tag | None {
        for held in self.tags() {
            if held.name == name {
                return held;
            }
        }
        return None;
    }

    """Add a tag at a place: there at every frame, turned as the model is."""
    def add_tag(name: str, at: Vec3) -> Tag | None {
        if not name or self.tag(name) is not None {
            return None;
        }
        made = Tag(name=name);
        for index in range(max(1, self.frames())) {
            made.origins.append(at);
            made.axes.append([Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]);
        }
        self +>:HasTag:+> made;
        self.dirty = True;
        self.revision += 1;
        return made;
    }

    def drop_tag(name: str) -> bool {
        held = self.tag(name);
        if held is None {
            return False;
        }
        self del->:HasTag:-> held;
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    """Put a tag somewhere else: at the frame in hand, or at every frame."""
    def move_tag(name: str, at: Vec3, every: bool = False) -> bool {
        held = self.tag(name);
        if held is None {
            return False;
        }
        while len(held.origins) < self.frames() {
            # A tag from before the model had so many frames.
            held.origins.append(held.origins[-1] if len(held.origins) > 0 else at);
            held.axes.append([Vec3(x=1.0), Vec3(y=1.0), Vec3(z=1.0)]);
        }
        for index in range(len(held.origins)) {
            if every or index == self.frame {
                held.origins[index] = at;
            }
        }
        self.dirty = True;
        self.revision += 1;
        return True;
    }

    """Turn a tag about one of the world's axes where it stands, by degrees:
    at the frame in hand, or at every frame. What hangs from it turns with it."""
    def turn_tag(name: str, axis: int, degrees: float, every: bool = False) -> bool {
        held = self.tag(name);
        if held is None or axis < 0 or axis > 2 or degrees % 360.0 == 0.0 {
            return False;
        }
        swing = math.radians(degrees);
        first = (axis + 1) % 3;
        second = (axis + 2) % 3;
        for index in range(len(held.axes)) {
            if not (every or index == self.frame) {
                continue;
            }
            turned: list[Vec3] = [];
            for way in held.axes[index] {
                parts = [way.x, way.y, way.z];
                kept = parts[first] * math.cos(swing) - parts[second] * math.sin(swing);
                parts[second] = parts[first] * math.sin(swing) + parts[second] * math.cos(swing);
                parts[first] = kept;
                turned.append(Vec3(x=parts[0], y=parts[1], z=parts[2]));
            }
            held.axes[index] = turned;
        }
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

    # ------------------------------------------------------------------
    # Bones (impl/document.rig.impl.jac)

    def bones -> list[Bone] {
        return [self->:HasBone:->][?:Bone];
    }

    def bone(name: str) -> Bone | None;
    """The bone a bone hangs from, and those that hang from it."""
    def bone_parent(bone: Bone) -> Bone | None;
    def bone_children(bone: Bone) -> list[Bone];
    """Add a bone from one place to another, the same at every frame,
    hanging from the bone named (from none when no name is given). None
    when the name is taken or empty, or there is no such bone to hang from."""
    def add_bone(name: str, head: Vec3, tail: Vec3, parent: str = "") -> Bone | None;
    """Carry a chain on: a new bone from the end of one to a place, hanging
    from it."""
    def continue_bone(parent: str, name: str, tail: Vec3) -> Bone | None;
    """Take a bone away: what hung from it hangs from what it hung from,
    and the points it carried are carried by nothing."""
    def drop_bone(name: str) -> bool;
    """Put one end of a bone somewhere else at the frame in hand (or at
    every frame), leaving what it carries where it is."""
    def set_bone_end(name: str, tail: bool, at: Vec3, every: bool = False) -> bool;
    def tint_bone(name: str, tint: int) -> bool;
    """The grip a bone has on a part (made when asked for and missing)."""
    def grip(bone: Bone, part: Part, make: bool = False) -> Grip | None;
    """Give a bone points of the part in hand to carry, each by a weight;
    what other bones carry of them is cut down to what is left of one
    whole. Answers how many points the bone took."""
    def hold_points(name: str, points: list[int], weight: float = 1.0) -> int;
    """Let go points of the part in hand: from the bone named, or from every
    bone when no name is given. Answers how many were let go."""
    def release_points(points: list[int], name: str = "") -> int;
    """Give every point of every part to the bone it is nearest at the
    frame in hand, wholly. Answers how many points were given."""
    def hold_nearest -> int;
    """How much of a point of the part in hand each bone carries: the bones'
    names and their shares, for those that carry any."""
    def point_shares(point: int) -> list[tuple[str, float]];
    """The colour each point of a part is shown in: its bones' colours mixed
    by their shares, what is left of one whole going to `plain`."""
    def point_tints(part: Part, plain: int = 0x9a9a9a) -> list[int];
    """Every part and every bone as they stand, to undo a pose to."""
    def rig_states -> list[BoneState];
    """Turn a bone about its joint by degrees round an axis, at the frame in
    hand: what it carries goes with it by its shares, and all that hangs
    from it goes round whole. One edit."""
    def swing_bone(name: str, axis: Vec3, degrees: float) -> bool;
    """Move a bone and all that hangs from it, at the frame in hand."""
    def shift_bone(name: str, delta: Vec3) -> bool;
    """Spread the frames between two evenly: points and bones' ends alike."""
    def spread_frames(first: int, last: int) -> bool;
    """Keep an edit that changed parts and bones: what stood before, against
    what stands now. False when nothing changed."""
    def keep_pose(
        label: str, parts_before: list[PartState], bones_before: list[BoneState]
    ) -> bool;
    """The bones as text, to keep beside a model's file, and read back."""
    def rig_text -> str;
    def read_rig(text: str) -> int;
}
