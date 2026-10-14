"""The studio driven from outside, in sight. Requests come as files of
console commands in a folder (QP_CONTROL, or `ed_control listen <folder>`):
each is run in the studio's own console, line by line where the window and
the log panel show it, and when its last line has run an answer is written
beside it as JSON: what the console said, what was made, what was asked for.
`scripts/qpctl` sends a request and prints its answer.

With it come the commands that make driving the studio exact and watchable:
brushes and entities put at coordinates (not where the camera looks), the
document read back as JSON, the camera flown to a place over real seconds,
and the console held still for a while. A tool of the studio in a module of
its own (see editor/tools/host.jac)."""
import math;
import os;
import time;
import from engine.math.vec3 { Vec3 }
import from editor.tools.host { ToolHost, StudioTool }
import from editor.document.scene { Scene, Item, Solid, Finding, Holds, Owns }
import from editor.geometry.brush { box_sides, cylinder_sides, wedge_sides }

"""Lines the console printed that only echo a request's own commands; an
answer leaves them out of what was said."""
glob ECHO_MARK: str = "> ";

"""How many finished requests the desk keeps."""
glob KEPT_REQUESTS: int = 32;

"""A request from outside: its lines, how far it has got, and what its
answer is to carry."""
node Request {
    has seq: str = "",
        lines: list[str] = [],
        state: str = "waiting",
        # Where the console's printing stood, and the next serial the scene
        # would give, when it began.
        mark: int = 0,
        serial_from: int = 0,
        scene_name: str = "",
        began: float = 0.0,
        line_at: int = -1,
        data: list[str] = [],
        faults: list[str] = [];
}

"""Where requests are filed, in the order they came."""
node Desk {}

edge Filed: Desk --> Request {}

"""Walks the desk to the request of a number."""
walker FindRequest {
    has seq: str,
        found: Request | None = None;

    can start with Desk entry {
        visit [here->:Filed:->];
    }

    can check with Request entry {
        if here.seq == self.seq {
            self.found = here;
            disengage;
        }
    }
}

"""Walks a scene's entities and their brushes, writing each as JSON: those
of a class (all when none is named), and brushes with a material whose name
holds `material` (all when none is named). `serials` keeps to those numbers
when it is not empty."""
walker Survey {
    has classname: str = "",
        material: str = "",
        entities_wanted: bool = True,
        brushes_wanted: bool = True,
        serials: list[int] = [],
        entities: list[str] = [],
        brushes: list[str] = [];

    can start with Scene entry {
        visit [here->:Holds:->];
    }

    can entity with Item entry {
        if here.held {
            fits = (not self.classname or here.classname() == self.classname)
                and (len(self.serials) == 0 or here.serial in self.serials);
            if self.entities_wanted and fits {
                self.entities.append(item_json(here));
            }
            if self.brushes_wanted {
                visit [here->:Owns:->];
            }
        }
    }

    can brush with Solid entry {
        if here.held and (len(self.serials) == 0 or here.serial in self.serials) {
            names = solid_materials(here);
            if not self.material or len([name for name in names if self.material in name]) > 0 {
                owners = [here<-:Owns:<-][?:Item];
                self.brushes.append(solid_json(here, owners[0].serial if len(owners) > 0 else -1, names));
            }
        }
    }
}

"""A string as JSON."""
def json_text(text: str) -> str {
    parts: list[str] = ["\""];
    digits = "0123456789abcdef";
    for c in text {
        code = ord(c);
        if c == "\"" {
            parts.append("\\\"");
        } elif c == "\\" {
            parts.append("\\\\");
        } elif c == "\n" {
            parts.append("\\n");
        } elif c == "\r" {
            parts.append("\\r");
        } elif c == "\t" {
            parts.append("\\t");
        } elif code < 32 {
            parts.append("\\u00" + digits[code // 16] + digits[code % 16]);
        } else {
            parts.append(c);
        }
    }
    parts.append("\"");
    return "".join(parts);
}

"""A number as JSON: whole numbers without a point, others to a thousandth."""
def json_number(value: float) -> str {
    near = round(value, 3);
    if near == float(int(near)) {
        return str(int(near));
    }
    return str(near);
}

def json_texts(values: list[str]) -> str {
    return "[" + ",".join([json_text(value) for value in values]) + "]";
}

def json_point(at: Vec3) -> str {
    return "[" + json_number(at.x) + "," + json_number(at.y) + "," + json_number(at.z) + "]";
}

"""An entity as JSON: its number, class and fields."""
def item_json(item: Item) -> str {
    fields: list[str] = [];
    for key in sorted(item.fields.keys()) {
        fields.append(json_text(key) + ":" + json_text(item.fields[key]));
    }
    return "{\"serial\":" + str(item.serial) + ",\"classname\":" + json_text(item.classname()) + ",\"hidden\":"
        + ("true" if item.hidden else "false") + ",\"fields\":{" + ",".join(fields) + "}}";
}

"""The materials of a brush's sides, each once, in the order of its sides."""
def solid_materials(solid: Solid) -> list[str] {
    names: list[str] = [];
    for side in solid.sides {
        if side.material not in names {
            names.append(side.material);
        }
    }
    return names;
}

"""A brush as JSON: its number, the entity that owns it, its box and its
materials."""
def solid_json(solid: Solid, owner: int, materials: list[str]) -> str {
    box = solid.bounds();
    low = box[0] if box is not None else Vec3();
    high = box[1] if box is not None else Vec3();
    return "{\"serial\":" + str(solid.serial) + ",\"owner\":" + str(owner) + ",\"low\":" + json_point(low) + ",\"high\":"
        + json_point(high) + ",\"sides\":" + str(len(solid.sides)) + ",\"materials\":" + json_texts(materials) + "}";
}

"""A finding of the check as JSON: its words, the entity or brush it is
about (-1 for none) and whether it would stop the level playing."""
def finding_json(found: Finding) -> str {
    item = found.item;
    solid = found.solid;
    return "{\"words\":" + json_text(found.words) + ",\"entity\":" + str(item.serial if item is not None else -1)
        + ",\"brush\":" + str(solid.serial if solid is not None else -1) + ",\"grave\":" + ("true" if found.grave else "false")
        + "}";
}

"""The first serial a request made in a scene: none, when the request has
gone to another document (opened or started one), whose contents it did
not make one by one."""
def made_from(request: Request, scene: Scene) -> int {
    return request.serial_from if scene.name == request.scene_name else scene.next_serial;
}

"""So many numbers read from the words from `start` on; None when there are
too few or one is not a number."""
def numbers_from(args: list[str], start: int, count: int) -> list[float] | None {
    if len(args) < start + count {
        return None;
    }
    found: list[float] = [];
    for i in range(count) {
        try {
            found.append(float(args[start + i]));
        } except ValueError {
            return None;
        }
    }
    return found;
}

"""What a request's file may be called: its number, made of letters, digits,
dashes and underscores."""
def request_name(name: str) -> str {
    if not name.endswith(".cmd") or name.startswith(".") {
        return "";
    }
    seq = name[:-4];
    for c in seq {
        if not (c.isalnum() or c == "-" or c == "_") {
            return "";
        }
    }
    return seq;
}

"""The console lines a request is run as: a step that begins it, each line
of it after a step that echoes it in the log (not `wait`, which only lets a
frame pass), and a step that answers it."""
def request_script(seq: str, lines: list[str]) -> str {
    parts: list[str] = ["ed_control begin " + seq];
    for i in range(len(lines)) {
        line = lines[i].strip();
        if not line or line.startswith("//") {
            continue;
        }
        if line != "wait" {
            parts.append("ed_control line " + seq + " " + str(i));
        }
        parts.append(line);
    }
    parts.append("ed_control end " + seq);
    return "\n".join(parts);
}

"""How far along a flight is at `t` (0 to 1): slow to start and to stop."""
def eased(t: float) -> float {
    t = max(0.0, min(1.0, t));
    return t * t * (3.0 - 2.0 * t);
}

"""The turn from one heading to another the short way round, in degrees."""
def turn_between(start: float, finish: float) -> float {
    turn = (finish - start) % 360.0;
    return turn - 360.0 if turn > 180.0 else turn;
}

"""The yaw and pitch, in degrees, that look from `eye` at `target`."""
def look_angles(eye: Vec3, target: Vec3) -> list[float] {
    way = target.sub(eye);
    across = math.sqrt(way.x * way.x + way.y * way.y);
    yaw = math.degrees(math.atan2(way.y, way.x)) if across > 0.0001 else 0.0;
    return [yaw, math.degrees(math.atan2(way.z, across))];
}

obj Control(StudioTool) {
    has folder: str = "",
        looked: bool = False,
        due: float = 0.0,
        desk: Desk = Desk(),
        served: int = 0,
        running: str = "",
        # The console is held until then (time.time()), or while flying.
        hold_until: float = 0.0,
        flying: bool = False,
        fly_from: list[float] = [],
        fly_to: list[float] = [],
        fly_began: float = 0.0,
        fly_seconds: float = 0.0;

    def commands -> list[tuple[str, str, str]] {
        return [
            (
                "ed_control",
                "ed_control [listen <folder> | stop]",
                "take requests of console commands from files in a folder, run them in sight, and answer each as JSON (scripts/qpctl)"
            ),
            ("ed_box_at", "ed_box_at <x0 y0 z0> <x1 y1 z1> [material]", "add a box brush between two corners"),
            (
                "ed_cylinder_at",
                "ed_cylinder_at <x0 y0 z0> <x1 y1 z1> [material] [sides]",
                "add an upright cylinder brush filling the box between two corners"
            ),
            ("ed_wedge_at", "ed_wedge_at <x0 y0 z0> <x1 y1 z1> [material]", "add a wedge brush filling the box between two corners"),
            ("ed_put", "ed_put <classname> <x y z> [key value ...]", "add an entity at a point, with its fields"),
            (
                "ed_query",
                "ed_query <scene|entities [class]|brushes [material]|selection|made|camera|findings>",
                "the document as JSON: in a request's answer, or the console"
            ),
            (
                "ed_fly",
                "ed_fly <x y z> [<yaw pitch> | at <x y z>] [seconds]",
                "fly the camera to a place, looking a way or at a point, over so many seconds (the console waits)"
            ),
            ("ed_sleep", "ed_sleep <seconds>", "hold the console still for so many seconds, the window going on"),
            ("ed_note", "ed_note <words>", "say something in the status bar and the log, to show what is being done")
        ];
    }

    def command(host: ToolHost, scene: Scene, args: list[str]) -> bool {
        name = args[0];
        if name == "ed_control" {
            self.control(host, args);
        } elif name == "ed_box_at" or name == "ed_cylinder_at" or name == "ed_wedge_at" {
            self.put_brush(host, scene, args);
        } elif name == "ed_put" {
            self.put_entity(host, args);
        } elif name == "ed_query" {
            self.query(host, args);
        } elif name == "ed_fly" {
            self.fly(host, args);
        } elif name == "ed_sleep" {
            seconds = numbers_from(args, 1, 1);
            if seconds is None {
                self.fault(host, "ed_sleep <seconds>");
            } else {
                self.hold_until = time.time() + max(0.0, seconds[0]);
                host.queue_first("ed_control hold");
            }
        } elif name == "ed_note" {
            host.say(" ".join(args[1:]));
        } else {
            return False;
        }
        return True;
    }

    def draw_through(host: ToolHost, scene: Scene) {}

    def tick(host: ToolHost, dt: float) {
        if not self.looked {
            self.looked = True;
            asked = os.getenv("QP_CONTROL", "");
            if asked {
                self.listen(host, asked);
            }
        }
        if not self.folder {
            return;
        }
        self.due -= dt;
        if self.due > 0.0 {
            return;
        }
        self.due = 0.1;
        self.collect(host);
    }

    def dump_lines(host: ToolHost, scene: Scene) -> list[str] {
        if not self.folder {
            return [];
        }
        return ["studio: control folder=" + self.folder + " served=" + str(self.served) + " running=" + (self.running or "-")];
    }

    def settings_lines(host: ToolHost) -> list[str] {
        return [];
    }

    # ------------------------------------------------------------------
    # Requests

    def listen(host: ToolHost, folder: str) {
        folder = folder.rstrip("/") or "/";
        try {
            os.makedirs(folder + "/in", exist_ok=True);
            os.makedirs(folder + "/out", exist_ok=True);
            # Who takes the folder's requests: qpctl starts no second studio on it.
            with open(folder + "/studio.pid", "w") as file {
                file.write(str(os.getpid()) + "\n");
            }
        } except OSError as error {
            host.say("ed_control: cannot use " + folder + ": " + str(error));
            return;
        }
        self.folder = folder;
        self.due = 0.0;
        host.say("Taking requests from " + folder + "/in");
    }

    """Take the requests waiting in the folder, oldest name first, and hand
    each to the console whole."""
    def collect(host: ToolHost) {
        inbox = self.folder + "/in";
        try {
            names = sorted(os.listdir(inbox));
        } except OSError {
            return;
        }
        for name in names {
            seq = request_name(name);
            if not seq {
                continue;
            }
            path = inbox + "/" + name;
            text = "";
            try {
                with open(path, "r") as file {
                    text = file.read();
                }
                os.remove(path);
            } except OSError {
                continue;
            }
            request = Request(seq=seq, lines=text.split("\n"));
            self.desk +>:Filed:+> request;
            self.forget_old();
            host.queue(request_script(seq, request.lines));
        }
    }

    def forget_old {
        filed = [self.desk->:Filed:->][?:Request];
        finished = [request for request in filed if request.state == "done"];
        for i in range(max(0, len(finished) - KEPT_REQUESTS)) {
            self.desk del->:Filed:-> finished[i];
        }
    }

    def find(seq: str) -> Request | None {
        finder = FindRequest(seq=seq);
        self.desk spawn finder;
        return finder.found;
    }

    """The request being run now, if any."""
    def current -> Request | None {
        return self.find(self.running) if self.running else None;
    }

    """Note what went wrong: in the request being run, and on screen."""
    def fault(host: ToolHost, words: str) {
        request = self.current();
        if request is not None {
            request.faults.append(words);
        }
        host.say(words);
    }

    """Hand a result to the request being run, or print it when none is."""
    def give(host: ToolHost, result: str) {
        request = self.current();
        if request is not None {
            request.data.append(result);
        } else {
            host.echo(result);
        }
    }

    def control(host: ToolHost, args: list[str]) {
        how = args[1] if len(args) > 1 else "";
        if how == "listen" {
            if len(args) > 2 {
                self.listen(host, args[2]);
            } else {
                host.say("ed_control listen <folder>");
            }
        } elif how == "stop" {
            self.folder = "";
            host.say("No longer taking requests");
        } elif how == "begin" and len(args) > 2 {
            request = self.find(args[2]);
            if request is not None {
                request.state = "running";
                request.mark = host.heard();
                request.began = time.time();
                scene = host.scene_now();
                request.serial_from = scene.next_serial if scene is not None else 0;
                request.scene_name = scene.name if scene is not None else "";
                self.running = request.seq;
            }
        } elif how == "line" and len(args) > 3 {
            request = self.find(args[2]);
            if request is not None and args[3].isdigit() and int(args[3]) < len(request.lines) {
                request.line_at = int(args[3]);
                host.echo(ECHO_MARK + request.lines[request.line_at].strip());
            }
        } elif how == "end" and len(args) > 2 {
            request = self.find(args[2]);
            if request is not None {
                self.answer(host, request);
            }
        } elif how == "hold" {
            self.hold(host);
        } else {
            where = self.folder if self.folder else "nowhere (ed_control listen <folder>)";
            host.say("Taking requests from " + where + "; " + str(self.served) + " answered");
        }
    }

    """Write a request's answer beside it, once its last line has run."""
    def answer(host: ToolHost, request: Request) {
        request.state = "done";
        self.running = "";
        self.served += 1;
        said = [line for line in host.heard_since(request.mark) if not line.startswith(ECHO_MARK)];
        faults = list(request.faults) + [line for line in said if line.startswith("Unknown command")];
        scene = host.scene_now();
        made_entities: list[str] = [];
        made_brushes: list[str] = [];
        summary = "null";
        if scene is not None {
            survey = Survey();
            scene spawn survey;
            begun = made_from(request, scene);
            made = Survey(serials=[serial for serial in range(begun, scene.next_serial)]);
            if scene.next_serial > begun {
                scene spawn made;
                made_entities = made.entities;
                made_brushes = made.brushes;
            }
            summary = "{\"switched\":" + ("false" if scene.name == request.scene_name else "true") + ",\"game\":" + json_text(scene.game) + ",\"name\":" + json_text(scene.name) + ",\"path\":"
                + json_text(scene.path) + ",\"entities\":" + str(len(survey.entities)) + ",\"brushes\":"
                + str(len(survey.brushes)) + ",\"selected\":" + str(len(scene.selection()) + len(scene.selected_solids()))
                + ",\"dirty\":" + ("true" if scene.dirty else "false") + "}";
        }
        text = "{\"seq\":" + json_text(request.seq) + ",\"ok\":" + ("true" if len(faults) == 0 else "false") + ",\"seconds\":"
            + json_number(time.time() - request.began) + ",\"faults\":" + json_texts(faults) + ",\"said\":"
            + json_texts(said) + ",\"made\":{\"entities\":[" + ",".join(made_entities) + "],\"brushes\":["
            + ",".join(made_brushes) + "]},\"data\":[" + ",".join(request.data) + "],\"scene\":" + summary
            + ",\"camera\":" + self.camera_json(host) + ",\"playing\":" + ("true" if host.playing() else "false") + "}\n";
        if not self.folder {
            return;
        }
        final = self.folder + "/out/" + request.seq + ".json";
        try {
            with open(final + ".part", "w") as file {
                file.write(text);
            }
            os.replace(final + ".part", final);
        } except OSError as error {
            host.say("ed_control: cannot write " + final + ": " + str(error));
        }
    }

    def camera_json(host: ToolHost) -> str {
        view = host.camera();
        return "[" + ",".join([json_number(value) for value in view]) + "]";
    }

    # ------------------------------------------------------------------
    # Things put where they are asked to be

    def put_brush(host: ToolHost, scene: Scene, args: list[str]) {
        name = args[0];
        corners = numbers_from(args, 1, 6);
        if corners is None {
            self.fault(host, name + " <x0 y0 z0> <x1 y1 z1> [material]" + (" [sides]" if name == "ed_cylinder_at" else ""));
            return;
        }
        low = Vec3(x=min(corners[0], corners[3]), y=min(corners[1], corners[4]), z=min(corners[2], corners[5]));
        high = Vec3(x=max(corners[0], corners[3]), y=max(corners[1], corners[4]), z=max(corners[2], corners[5]));
        material = args[7] if len(args) > 7 and args[7] else host.material_in_hand();
        if name == "ed_cylinder_at" {
            count = int(args[8]) if len(args) > 8 and args[8].isdigit() else 12;
            sides = cylinder_sides(low, high, max(3, count), material);
        } elif name == "ed_wedge_at" {
            sides = wedge_sides(low, high, material);
        } else {
            sides = box_sides(low, high, material);
        }
        if scene.create_solid(sides) is None {
            self.fault(host, name + ": that box encloses nothing");
        } else {
            host.say("Added a " + name[3:-3] + " of " + material);
        }
    }

    def put_entity(host: ToolHost, args: list[str]) {
        at = numbers_from(args, 2, 3);
        if at is None or (len(args) - 5) % 2 != 0 {
            self.fault(host, "ed_put <classname> <x y z> [key value ...]");
            return;
        }
        host.run(["ed_new", args[1]]);
        scene = host.scene_now();
        if scene is None or len(scene.selection()) != 1 or scene.selection()[0].classname() != args[1] {
            self.fault(host, "ed_put: " + args[1] + " was not added");
            return;
        }
        pairs: dict[str, str | None] = {"origin": json_number(at[0]) + " " + json_number(at[1]) + " " + json_number(at[2])};
        for i in range(5, len(args), 2) {
            pairs[args[i]] = args[i + 1];
        }
        scene.set_fields(pairs, "Put " + args[1]);
    }

    # ------------------------------------------------------------------
    # The document read back

    def query(host: ToolHost, args: list[str]) {
        what = args[1] if len(args) > 1 else "scene";
        scene = host.scene_now();
        if what == "camera" {
            self.give(host, "{\"camera\":" + self.camera_json(host) + "}");
            return;
        }
        if what == "findings" {
            host.run(["ed_check"]);
            self.give(host, "{\"findings\":[" + ",".join([finding_json(found) for found in host.findings()]) + "]}");
            return;
        }
        if scene is None {
            self.fault(host, "ed_query: no scene is open");
            return;
        }
        survey = Survey();
        if what == "entities" {
            survey.brushes_wanted = False;
            survey.classname = args[2] if len(args) > 2 else "";
        } elif what == "brushes" {
            survey.entities_wanted = False;
            survey.material = args[2] if len(args) > 2 else "";
        } elif what == "selection" {
            survey.serials = [item.serial for item in scene.selection()] + [solid.serial for solid in scene.selected_solids()];
            if len(survey.serials) == 0 {
                self.give(host, "{\"entities\":[],\"brushes\":[]}");
                return;
            }
        } elif what == "made" {
            request = self.current();
            begun = made_from(request, scene) if request is not None else scene.next_serial;
            survey.serials = [serial for serial in range(begun, scene.next_serial)];
            if len(survey.serials) == 0 {
                self.give(host, "{\"entities\":[],\"brushes\":[]}");
                return;
            }
        } elif what != "scene" {
            self.fault(host, "ed_query <scene|entities [class]|brushes [material]|selection|made|camera|findings>");
            return;
        }
        scene spawn survey;
        self.give(host, "{\"entities\":[" + ",".join(survey.entities) + "],\"brushes\":[" + ",".join(survey.brushes) + "]}");
    }

    # ------------------------------------------------------------------
    # The camera flown and the console held, in real seconds

    def fly(host: ToolHost, args: list[str]) {
        usage = "ed_fly <x y z> [<yaw pitch> | at <x y z>] [seconds]";
        eye = numbers_from(args, 1, 3);
        if eye is None {
            self.fault(host, usage);
            return;
        }
        here = host.camera();
        place = Vec3(x=eye[0], y=eye[1], z=eye[2]);
        angles = [here[3], here[4]];
        rest = 4;
        if len(args) > 4 and args[4] == "at" {
            target = numbers_from(args, 5, 3);
            if target is None {
                self.fault(host, usage);
                return;
            }
            angles = look_angles(place, Vec3(x=target[0], y=target[1], z=target[2]));
            rest = 8;
        } elif numbers_from(args, 4, 2) is not None {
            turned = numbers_from(args, 4, 2);
            angles = [turned[0], turned[1]] if turned is not None else angles;
            rest = 6;
        }
        seconds = 1.5;
        if len(args) > rest {
            taken = numbers_from(args, rest, 1);
            if taken is None {
                self.fault(host, usage);
                return;
            }
            seconds = max(0.0, taken[0]);
        }
        self.fly_from = here;
        self.fly_to = [place.x, place.y, place.z, here[3] + turn_between(here[3], angles[0]), angles[1]];
        self.fly_began = time.time();
        self.fly_seconds = seconds;
        self.flying = True;
        self.steer(host);
        if self.flying {
            host.queue_first("ed_control hold");
        }
    }

    """Put the camera where the flight has got to."""
    def steer(host: ToolHost) {
        if not self.flying {
            return;
        }
        t = 1.0 if self.fly_seconds <= 0.0 else (time.time() - self.fly_began) / self.fly_seconds;
        if t >= 1.0 {
            self.flying = False;
            t = 1.0;
        }
        k = eased(t);
        at = [self.fly_from[i] + (self.fly_to[i] - self.fly_from[i]) * k for i in range(5)];
        host.aim(Vec3(x=at[0], y=at[1], z=at[2]), at[3], at[4]);
    }

    """A held console: let a frame pass and look again, until the time is
    up and the camera has landed."""
    def hold(host: ToolHost) {
        self.steer(host);
        if self.flying or time.time() < self.hold_until {
            host.queue_first("wait\ned_control hold");
        }
    }
}
