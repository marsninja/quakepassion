"""Archive access and model adaptation shared by all three games."""
import os;
import from .pak { PakArchive, open_pak }
import from .pk3 { Pk3Assets }
import from ..formats.animated { AnimatedModel }
import from ..formats.bsp { Texture }
import from ..formats.q1.model { parse_mdl }
import from ..formats.q1.item_model { parse_item_bsp }
import from ..formats.q2.model { parse_md2, parse_pcx }
import from ..formats.q3.model { parse_md3 }

obj ModelAsset {
    has model: AnimatedModel,
        skins: list[Texture];
}

obj AssetLibrary {
    has game: str,
        paks: list[PakArchive] = [],
        pk3: Pk3Assets = Pk3Assets(),
        cache: dict[str, ModelAsset] = {};

    def open(directory: str) {
        self.close();
        if self.game == "q3" {
            self.pk3.open(directory);
        } elif self.game == "q1" or self.game == "q2" {
            for filename in sorted(os.listdir(directory)) {
                if filename.lower().endswith(".pak") {
                    self.paks.append(open_pak(directory + "/" + filename));
                }
            }
        } else {
            raise ValueError("Unknown game asset format");
        }
    }

    def read(name: str) -> bytes {
        if self.game == "q3" {
            return self.pk3.read(name);
        }
        for archive in reversed(self.paks) {
            if archive.has_file(name) {
                return archive.read_file(name);
            }
        }
        raise ValueError("Missing game asset: " + name);
    }

    def model(name: str, skin: int = 0) -> ModelAsset {
        key = name + ":" + str(skin);
        if key in self.cache {
            return self.cache[key];
        }
        model = AnimatedModel();
        skins: list[Texture] = [];
        if self.game == "q1" {
            if name.endswith(".bsp") {
                model = parse_item_bsp(self.read(name), self.read("gfx/palette.lmp"));
                for surface in model.surfaces {
                    skins.append(surface.embedded_skins[0]);
                }
                result = ModelAsset(model=model, skins=skins);
                self.cache[key] = result;
                return result;
            }
            model = parse_mdl(self.read(name), self.read("gfx/palette.lmp"));
            for surface in model.surfaces {
                if skin < 0 or skin >= len(surface.skin_groups) {
                    raise ValueError("MDL skin out of range");
                }
                skins.append(surface.embedded_skins[surface.skin_groups[skin].first]);
            }
        } elif self.game == "q2" {
            model = parse_md2(self.read(name));
            for surface in model.surfaces {
                if skin < 0 or skin >= len(surface.skins) {
                    raise ValueError("MD2 skin out of range");
                }
                skins.append(
                    parse_pcx(self.read(surface.skins[skin]), surface.skins[skin])
                );
            }
        } elif self.game == "q3" {
            model = parse_md3(self.read(name));
            for surface in model.surfaces {
                if skin < 0 or skin >= len(surface.skins) {
                    raise ValueError("MD3 surface needs a skin mapping");
                }
                texture = Texture(name=surface.skins[skin]);
                surface.stages = self.pk3.model_stages(surface.skins[skin]);
                self.pk3.texture(texture);
                if not texture.encoded {
                    raise ValueError("Missing model material: " + texture.name);
                }
                skins.append(texture);
            }
        } else {
            raise ValueError("Unknown game model format");
        }
        result = ModelAsset(model=model, skins=skins);
        self.cache[key] = result;
        return result;
    }

    def close() {
        self.pk3.close();
        self.paks = [];
        self.cache = {};
    }
}
