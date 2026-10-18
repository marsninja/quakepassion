"""Everything in the installed games' archives, as folders of files.

Quake and Quake II keep their files in PAKs and Quake III in PK3s, later
archives over earlier ones. The index lists each game's files once, by
folder, and reads any of them, through the same catalog the materials come
from."""
import os;
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.q2.model { parse_pcx }
import from engine.formats.q1.sprite { parse_spr }
import from engine.formats.q2.sprite { parse_sp2 }
import from engine.formats.q2.cin { open_cin, cinematic_rgba }
import from engine.formats.q3.roq { open_roq }
import from engine.formats.film { Film }
import from engine.formats.wav { parse_wav_pcm }
import from engine.formats.q1.wad { indexed_rgba }
import from ..formats.archive { folder_children, file_kind, wad_member, wad_names, wad_lump }
import from .materials { ArchiveMaterials }

"""Every file under a folder on disk, by its path from the folder, sorted.
Files and folders whose names begin with a dot are left out."""
def own_files(folder: str) -> list[str] {
    found: list[str] = [];
    if not folder or not os.path.isdir(folder) {
        return found;
    }
    waiting = [""];
    while len(waiting) > 0 {
        inside = waiting.pop();
        try {
            entries = sorted(os.listdir(folder + "/" + inside if inside else folder));
        } except Exception {
            continue;
        }
        for found_name in entries {
            if found_name.startswith(".") {
                continue;
            }
            whole = inside + "/" + found_name if inside else found_name;
            if os.path.isdir(folder + "/" + whole) {
                waiting.append(whole);
            } else {
                found.append(whole);
            }
        }
    }
    return sorted(found);
}

"""A texture's colours, four bytes a texel: its own when it has them, or its
pixels when they are that (the games' model, sprite and PCX readers leave
them there). Empty when it has neither."""
def texture_rgba(image: Texture) -> bytes {
    wanted = image.width * image.height * 4;
    if wanted <= 0 {
        return b"";
    }
    if len(image.rgba) >= wanted {
        return image.rgba;
    }
    if len(image.pixels) >= wanted {
        return image.pixels;
    }
    return b"";
}

"""A file that is a run of pictures: a sprite's frames, all of them; or a
film, read a picture at a time as its decoder gives them (forward only).
`index` is the picture showing; `total` how many there are (0 for a film,
whose length is not known until it runs out)."""
obj AssetReel {
    has frames: list[Texture] = [],
        film: Film | None = None,
        total: int = 0,
        index: int = 0,
        rate: int = 10,
        ended: bool = False,
        # The sound read with the film's last picture, not yet played: in the
        # layout the engine's raw channel takes.
        heard: bytes = b"",
        heard_rate: int = 0,
        heard_width: int = 0,
        heard_channels: int = 0;
}

"""The picture a film's decoder gives next, as a texture: None once the
film has run out."""
def film_picture(film: Film, name: str, reel: AssetReel | None = None) -> Texture | None {
    read = film.next_picture();
    if read is None or film.width <= 0 or film.height <= 0 {
        return None;
    }
    if reel is not None and len(read.samples) > 0 {
        # Its sound, kept with what is still to be played.
        reel.heard = reel.heard + read.samples;
        reel.heard_rate = read.sound_rate;
        reel.heard_width = read.sound_width;
        reel.heard_channels = read.sound_channels;
    }
    pixels = cinematic_rgba(read.pixels, read.palette) if len(read.palette) == 768 else read.pixels;
    if len(pixels) < film.width * film.height * 4 {
        return None;
    }
    return Texture(name=name, width=film.width, height=film.height, rgba=pixels);
}

"""The next picture of a reel, and the reel moved on to it: a sprite's
frames go round; a film's are read on, and None is the answer once it has
run out (the reel is then `ended`)."""
def reel_next(reel: AssetReel, name: str = "") -> Texture | None {
    film = reel.film;
    if film is not None {
        if reel.ended {
            return None;
        }
        shown = film_picture(film, name, reel);
        if shown is None {
            reel.ended = True;
            return None;
        }
        reel.index += 1;
        return shown;
    }
    if reel.total <= 0 {
        return None;
    }
    reel.index = (reel.index + 1) % reel.total;
    return reel.frames[reel.index];
}

"""The picture before, for a reel whose pictures are all there (a sprite);
None for a film, which is read forward only."""
def reel_before(reel: AssetReel) -> Texture | None {
    if reel.film is not None or reel.total <= 0 {
        return None;
    }
    reel.index = (reel.index + reel.total - 1) % reel.total;
    return reel.frames[reel.index];
}

"""What the explorer shows of one file."""
obj AssetLook {
    has game: str = "",
        name: str = "",
        kind: str = "other",
        size: int = 0,
        # What it says about itself: an image's size, a sound's length.
        note: str = "",
        # An image to show, when it is one.
        image: Texture | None = None,
        # The first lines of a text file.
        lines: list[str] = [],
        # The material name a scene would use it by, when it is a texture.
        material: str = "",
        # Its pictures, when it is a sprite or a film.
        reel: AssetReel | None = None;
}

obj AssetIndex {
    has shelf: ArchiveMaterials,
        listed: dict[str, list[str]] = {},
        # A folder of the user's own (an open project's), listed beside the
        # games as "own": its files are on disk, and are read afresh.
        home: str = "";

    """The games whose archives are there, and the user's own folder when there is one."""
    def games -> list[str] {
        found = [game for game in ["q1", "q2", "q3"] if self.shelf.has_game(game)];
        if self.home and os.path.isdir(self.home) {
            found.append("own");
        }
        return found;
    }

    """Every file of a game, once, sorted."""
    def names(game: str) -> list[str] {
        if game == "own" {
            return own_files(self.home);
        }
        if game in self.listed {
            return self.listed[game];
        }
        seen: dict[str, bool] = {};
        try {
            library = self.shelf.reader().catalog.source(game);
            if game == "q3" {
                for name in library.pk3.owners.keys() {
                    seen[name] = True;
                }
            } else {
                for archive in library.paks {
                    for name in archive.names() {
                        seen[name] = True;
                    }
                }
            }
        } except Exception {
            seen = {};
        }
        # A name that climbs out of its folder (../COPYING) is never listed,
        # so nothing extracts it outside the folder it is written under.
        found = [
            name for name in seen.keys()
            if name and not name.endswith("/") and not name.startswith("/") and ".." not in name.split("/")
        ];
        # A WAD is a folder of its lumps as well as a file.
        inside: list[str] = [];
        for name in found {
            if name.lower().endswith(".wad") {
                held = self.read(game, name);
                if held is not None {
                    inside.extend(wad_names(name, held));
                }
            }
        }
        found = sorted(found + inside);
        self.listed[game] = found;
        return found;
    }

    def children(game: str, folder: str) -> tuple[list[str], list[str]] {
        return folder_children(self.names(game), folder);
    }

    """A file's bytes, or none when it cannot be read."""
    def read(game: str, name: str) -> bytes | None {
        if game == "own" {
            try {
                with open(self.home + "/" + name, "rb") as file {
                    return file.read();
                }
            } except Exception {
                return None;
            }
        }
        within = wad_member(name);
        try {
            if within is not None {
                lump = wad_lump(self.shelf.reader().catalog.source(game).read(within[0]), within[1]);
                return lump[0] if lump is not None else None;
            }
            return self.shelf.reader().catalog.source(game).read(name);
        } except Exception {
            return None;
        }
    }

    """A lump of a WAD as a picture: a picture with its size before it, or
    the console's sheet of letters. None for any other lump."""
    def lump_image(game: str, name: str) -> Texture | None {
        within = wad_member(name);
        if within is None {
            return None;
        }
        try {
            source = self.shelf.reader().catalog.source(game);
            lump = wad_lump(source.read(within[0]), within[1]);
            palette = source.read("gfx/palette.lmp");
            if lump is None or len(palette) < 768 {
                return None;
            }
            data = lump[0];
            if within[1].lower() == "conchars" and len(data) >= 128 * 128 {
                return Texture(name=name, width=128, height=128, rgba=indexed_rgba(data[:128 * 128], palette));
            }
            if lump[1] != 66 or len(data) < 8 {
                return None;
            }
            wide = int.from_bytes(data[0:4], "little");
            tall = int.from_bytes(data[4:8], "little");
            if wide <= 0 or tall <= 0 or wide > 1024 or tall > 1024 or 8 + wide * tall > len(data) {
                return None;
            }
            return Texture(name=name, width=wide, height=tall, rgba=indexed_rgba(data[8:8 + wide * tall], palette));
        } except Exception {
            return None;
        }
    }

    """A sprite's frames as pictures: Quake's carry their own, in Quake's
    palette; Quake II's name a PCX file each. None when it does not read."""
    def sprite_reel(game: str, name: str, data: bytes) -> AssetReel | None {
        frames: list[Texture] = [];
        try {
            if name.lower().endswith(".spr") {
                palette = self.read(game, "gfx/palette.lmp");
                if palette is None or len(palette) != 768 {
                    return None;
                }
                for held in parse_spr(data, palette, name) {
                    frames.append(held.image);
                }
            } else {
                for frame in parse_sp2(data) {
                    picture = self.read(game, frame.image);
                    if picture is None {
                        continue;
                    }
                    frames.append(parse_pcx(picture, frame.image));
                }
            }
        } except Exception {
            return None;
        }
        return AssetReel(frames=frames, total=len(frames));
    }

    """What to show of a file: its kind and size, and its picture, its
    first lines or what it says of itself."""
    def look(game: str, name: str, most: int = 200) -> AssetLook {
        shown = AssetLook(game=game, name=name, kind=file_kind(name));
        data = self.read(game, name);
        if data is None {
            shown.note = "could not be read";
            return shown;
        }
        shown.size = len(data);
        low = name.lower();
        if wad_member(name) is not None {
            # A lump of a WAD: a picture when it is one.
            picture = self.lump_image(game, name);
            shown.kind = "image" if picture is not None else "other";
            shown.image = picture;
            shown.note = str(picture.width) + " x " + str(picture.height) if picture is not None else "a lump of a WAD";
            return shown;
        }
        if low.endswith(".spr") or low.endswith(".sp2") {
            shown.kind = "sprite";
            reel = self.sprite_reel(game, name, data);
            if reel is not None and reel.total > 0 {
                shown.reel = reel;
                shown.image = reel.frames[0];
                shown.note = str(reel.total) + (" picture, " if reel.total == 1 else " pictures, ") + str(reel.frames[0].width)
                    + " x " + str(reel.frames[0].height);
            } else {
                shown.note = "a sprite that does not read";
            }
            return shown;
        }
        if low.endswith(".cin") or low.endswith(".roq") {
            shown.kind = "film";
            try {
                film: Film = open_cin(data) if low.endswith(".cin") else open_roq(data);
                first = film_picture(film, name);
                if first is not None {
                    shown.reel = AssetReel(film=film, index=0, rate=max(1, film.frame_rate));
                    shown.image = first;
                    shown.note = str(film.width) + " x " + str(film.height) + ", " + str(film.frame_rate) + " pictures a second";
                } else {
                    shown.note = "a film with no picture";
                }
            } except Exception {
                shown.note = "a film that does not read";
            }
            return shown;
        }
        if shown.kind == "image" {
            image: Texture | None = None;
            if game == "q2" and low.startswith("textures/") and low.endswith(".wal") {
                shown.material = "q2:" + name[9:-4];
                image = self.shelf.fetch(shown.material);
            } elif game == "own" and (low.endswith(".tga") or low.endswith(".jpg") or low.endswith(".png")) {
                # An image file of the project's: in its textures folder it is a material as it is.
                if low.startswith("textures/") {
                    shown.material = "file:" + name[9:];
                }
                image = Texture(name=name, encoded=data, extension=low[-4:]);
            } elif game == "q3" and (low.endswith(".tga") or low.endswith(".jpg")) {
                if low.startswith("textures/") {
                    shown.material = "q3:" + name[:-4];
                }
                image = Texture(name=name, encoded=data, extension=low[-4:]);
            } elif low.endswith(".pcx") {
                try {
                    image = parse_pcx(data, name);
                } except Exception {
                    image = None;
                }
            }
            shown.image = image;
            if image is not None and len(texture_rgba(image)) > 0 {
                shown.note = str(image.width) + " x " + str(image.height);
            }
        } elif shown.kind == "text" {
            try {
                text = data.decode("utf-8");
                rows = text.replace("\r", "").replace("\t", "    ").split("\n");
                shown.note = str(len(rows)) + " lines";
                shown.lines = rows[:most];
            } except Exception {
                shown.note = "not plain text";
            }
        } elif shown.kind == "sound" {
            try {
                sound = parse_wav_pcm(data);
                frames = sound.length // max(1, sound.frame_bytes());
                shown.note = str(sound.rate) + " Hz, " + str(sound.channels) + " channel"
                    + ("s" if sound.channels != 1 else "") + ", "
                    + str(round(float(frames) / float(max(1, sound.rate)), 2)) + " s";
            } except Exception {
                shown.note = "a sound";
            }
        }
        return shown;
    }
}
