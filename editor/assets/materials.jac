"""Materials from the games' own archives.

A material is named by where its image lives: `q1:e1m1/tech04_1` is a texture
inside a Quake map, `q2:e1u1/metal3_2` a Quake II wall texture, and
`q3:textures/base_wall/concrete` a Quake III image. Anything else, or
anything the archives do not hold, is a swatch (compile/live.jac)."""
import os;
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.q1.bsp { parse_bsp }
import from engine.formats.q2.model { parse_pcx }
import from games.passion.materials { Loader }
import from ..compile.live { Materials, swatch_texture }
import from ..formats.image { image_size, image_kind }

obj ArchiveMaterials(Materials) {
    # The folder holding id1, baseq2 and baseq3.
    has directory: str,
        catalog: AssetCatalog | None = None,
        loader: Loader | None = None,
        found: dict[str, Texture] = {},
        # Names asked for that no archive holds.
        missing: list[str] = [],
        listed: dict[str, list[str]] = {},
        # Where image files used as materials are kept, when a project says.
        folder: str = "",
        # Folders of image files from elsewhere, each by what its materials'
        # names begin with: `addon:castle` for what an add-on brings,
        # `link:stone` for a folder used where it lies.
        extras: dict[str, str] = {};

    def reader -> Loader {
        loader = self.loader;
        if loader is None {
            catalog = AssetCatalog(game="passion", directory=self.directory);
            self.catalog = catalog;
            loader = Loader(catalog=catalog);
            self.loader = loader;
        }
        return loader;
    }

    """Open every game's archives now, rather than at the first material
    each holds (each takes a moment to index): a game whose files are not
    there is passed over."""
    def open_all {
        self.reader();
        catalog = self.catalog;
        if catalog is None {
            return;
        }
        for game in ["q1", "q2", "q3"] {
            try {
                catalog.source(game);
            } except Exception {
                continue;
            }
        }
    }

    def texture(name: str) -> Texture {
        if name in self.found {
            return self.found[name];
        }
        image = self.fetch(name);
        if image is None {
            image = swatch_texture(name);
        }
        self.found[name] = image;
        return image;
    }

    """Where a project keeps image files of its own to use as materials."""
    def files_folder -> str {
        if self.folder {
            return self.folder;
        }
        folder = os.getenv("QP_TEXTURES", "");
        return folder if folder else os.getcwd() + "/textures";
    }

    """The image files there, as material names: `file:` and the path under
    the folder."""
    def file_names -> list[str] {
        return self.images_under(self.files_folder(), "file:");
    }

    """The image files of a folder from elsewhere, as material names: what
    the folder goes by (`addon:castle`, `link:stone`) and the path under it."""
    def extra_names(key: str) -> list[str] {
        if key not in self.extras {
            return [];
        }
        return self.images_under(self.extras[key], key + "/");
    }

    """The image files under a folder, each as `lead` and its path from it."""
    def images_under(top: str, lead: str) -> list[str] {
        found: list[str] = [];
        if not os.path.isdir(top) {
            return found;
        }
        waiting: list[str] = [""];
        while len(waiting) > 0 {
            part = waiting.pop();
            here = top + "/" + part if part else top;
            for entry_name in sorted(os.listdir(here)) {
                inner = part + "/" + entry_name if part else entry_name;
                if os.path.isdir(here + "/" + entry_name) {
                    waiting.append(inner);
                } elif image_kind(entry_name) {
                    found.append(lead + inner);
                }
            }
        }
        return sorted(found);
    }

    """A material's image from the archives or the project's own files, or none."""
    def fetch(name: str) -> Texture | None {
        parts = name.split(":", 1);
        path = "";
        if len(parts) == 2 and parts[0] == "file" and parts[1] and ".." not in parts[1] {
            path = self.files_folder() + "/" + parts[1];
        } elif len(parts) == 2 and parts[0] in ["addon", "link"] and ".." not in parts[1] {
            # A file of a folder from elsewhere: an add-on's, or one linked to.
            halves = parts[1].split("/", 1);
            if len(halves) != 2 or parts[0] + ":" + halves[0] not in self.extras or not halves[1] {
                return None;
            }
            path = self.extras[parts[0] + ":" + halves[0]] + "/" + halves[1];
        }
        if path {
            kind = image_kind(path);
            if not kind or not os.path.isfile(path) {
                return None;
            }
            data = b"";
            try {
                with open(path, "rb") as handle {
                    data = handle.read();
                }
            } except OSError {
                return None;
            }
            size = image_size(data, kind);
            if size[0] <= 0 or size[1] <= 0 {
                return None;
            }
            if kind == ".pcx" {
                # The window reads no PCX: its colours are read here, as the games' own are.
                try {
                    read = parse_pcx(data, name);
                    # The reader leaves its colours where a level keeps numbers into a palette: here they are colours.
                    return Texture(name=name, width=read.width, height=read.height, rgba=read.pixels);
                } except Exception {
                    return None;
                }
            }
            return Texture(name=name, width=size[0], height=size[1], encoded=data, extension=kind);
        }
        if len(parts) != 2 or parts[0] not in ["q1", "q2", "q3"] or not parts[1] {
            return None;
        }
        try {
            if parts[0] == "q1" {
                place = parts[1].split("/", 1);
                if len(place) != 2 {
                    return None;
                }
                return self.reader().q1(place[0], place[1]);
            }
            if parts[0] == "q2" {
                return self.reader().q2(parts[1]);
            }
            image = self.reader().q3(parts[1]);
            # Quake III keeps an image as its file; a level's own
            # coordinates need no size, but a brush's mapping does.
            size = image_size(image.encoded, image.extension);
            if size[0] > 0 and size[1] > 0 {
                image.width = size[0];
                image.height = size[1];
            }
            return image;
        } except Exception {
            if name not in self.missing {
                self.missing.append(name);
            }
            return None;
        }
    }

    """Whether a game's archives are there to read."""
    def has_game(game: str) -> bool {
        folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
        return os.path.isdir(self.directory + "/" + folder);
    }

    """The groups materials come in: a Quake map (`q1:e1m1`), a Quake II
    texture folder (`q2:e1u1`), a Quake III one (`q3:base_wall`)."""
    def groups -> list[str] {
        if "" in self.listed {
            return self.listed[""];
        }
        result: list[str] = [];
        try {
            if self.has_game("q1") {
                maps: list[str] = [];
                for archive in self.reader().catalog.source("q1").paks {
                    for name in archive.names() {
                        # Item boxes are maps too (b_*.bsp); they hold one texture each.
                        if name.startswith("maps/") and name.endswith(".bsp") and not name.startswith("maps/b_") {
                            maps.append("q1:" + name[5:-4]);
                        }
                    }
                }
                result.extend(sorted(maps));
            }
            if self.has_game("q2") {
                folders: list[str] = [];
                for archive in self.reader().catalog.source("q2").paks {
                    for name in archive.names() {
                        parts = name.split("/");
                        if len(parts) == 3 and parts[0] == "textures" and name.endswith(".wal") {
                            group = "q2:" + parts[1];
                            if group not in folders {
                                folders.append(group);
                            }
                        }
                    }
                }
                result.extend(sorted(folders));
            }
            if self.has_game("q3") {
                folders = [];
                for name in self.reader().catalog.source("q3").pk3.owners.keys() {
                    parts = name.split("/");
                    if len(parts) == 3 and parts[0] == "textures" and (name.endswith(".jpg") or name.endswith(".tga")) {
                        group = "q3:" + parts[1];
                        if group not in folders {
                            folders.append(group);
                        }
                    }
                }
                result.extend(sorted(folders));
            }
        } except Exception {
            result = [];
        }
        self.listed[""] = result;
        return result;
    }

    """The materials of a group, by the names scenes use."""
    def names(group: str) -> list[str] {
        if group in self.listed {
            return self.listed[group];
        }
        result: list[str] = [];
        parts = group.split(":", 1);
        if len(parts) == 2 and parts[0] in ["addon", "link"] {
            # Read each time: such a folder is changed by hand.
            return self.extra_names(group);
        }
        try {
            if len(parts) == 2 and parts[0] == "q1" {
                data = self.reader().catalog.source("q1").read("maps/" + parts[1] + ".bsp");
                for image in parse_bsp(data).textures {
                    if image.name and image.name != "missing" {
                        result.append("q1:" + parts[1] + "/" + image.name);
                    }
                }
            } elif len(parts) == 2 and parts[0] == "q2" {
                prefix = "textures/" + parts[1] + "/";
                for archive in self.reader().catalog.source("q2").paks {
                    for name in archive.names() {
                        if name.startswith(prefix) and name.endswith(".wal") {
                            result.append("q2:" + name[9:-4]);
                        }
                    }
                }
            } elif len(parts) == 2 and parts[0] == "q3" {
                prefix = "textures/" + parts[1] + "/";
                for name in self.reader().catalog.source("q3").pk3.owners.keys() {
                    if name.startswith(prefix) and (name.endswith(".jpg") or name.endswith(".tga")) {
                        result.append("q3:" + name[:-4]);
                    }
                }
            }
        } except Exception {
            result = [];
        }
        result = sorted(result);
        self.listed[group] = result;
        return result;
    }

    def close {
        catalog = self.catalog;
        if catalog is not None {
            catalog.close();
        }
        self.catalog = None;
        self.loader = None;
    }
}

"""A texture no bigger than `limit` on a side, for showing small: every
n-th texel of the original."""
def small_picture(image: Texture, limit: int = 72) -> Texture {
    longest = max(image.width, image.height);
    if longest <= limit or limit <= 0 or len(image.rgba) < image.width * image.height * 4 {
        return image;
    }
    width = max(1, image.width * limit // longest);
    height = max(1, image.height * limit // longest);
    pixels = bytearray(width * height * 4);
    for y in range(height) {
        row = (y * image.height // height) * image.width;
        for x in range(width) {
            source = (row + x * image.width // width) * 4;
            at = (y * width + x) * 4;
            pixels[at] = u8(image.rgba[source]);
            pixels[at + 1] = u8(image.rgba[source + 1]);
            pixels[at + 2] = u8(image.rgba[source + 2]);
            pixels[at + 3] = u8(255);
        }
    }
    return Texture(name=image.name, width=width, height=height, rgba=bytes(pixels));
}
