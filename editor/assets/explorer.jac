"""Everything in the installed games' archives, as folders of files.

Quake and Quake II keep their files in PAKs and Quake III in PK3s, later
archives over earlier ones. The index lists each game's files once, by
folder, and reads any of them, through the same catalog the materials come
from."""
import from engine.assets.catalog { AssetCatalog }
import from engine.formats.bsp { Texture }
import from engine.formats.q2.model { parse_pcx }
import from engine.formats.wav { parse_wav_pcm }
import from engine.formats.q1.wad { indexed_rgba }
import from ..formats.archive { folder_children, file_kind, wad_member, wad_names, wad_lump }
import from .materials { ArchiveMaterials }

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
        material: str = "";
}

obj AssetIndex {
    has shelf: ArchiveMaterials,
        listed: dict[str, list[str]] = {};

    """The games whose archives are there."""
    def games -> list[str] {
        return [game for game in ["q1", "q2", "q3"] if self.shelf.has_game(game)];
    }

    """Every file of a game, once, sorted."""
    def names(game: str) -> list[str] {
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
        found = [name for name in seen.keys() if name and not name.endswith("/")];
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
        if shown.kind == "image" {
            image: Texture | None = None;
            if game == "q2" and low.startswith("textures/") and low.endswith(".wal") {
                shown.material = "q2:" + name[9:-4];
                image = self.shelf.fetch(shown.material);
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
            if image is not None and len(image.rgba) > 0 {
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
