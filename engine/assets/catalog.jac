"""Namespaced access to independently owned source-game archives."""
import from .library { AssetLibrary, ModelAsset }
obj AssetCatalog {
    has game: str, directory: str, libraries: dict[str, AssetLibrary] = {};
    def source(game: str) -> AssetLibrary {
        if game not in ["q1", "q2", "q3"] { raise ValueError("Invalid asset namespace"); }
        if game not in self.libraries {
            library = AssetLibrary(game=game);
            folder = "id1" if game == "q1" else ("baseq2" if game == "q2" else "baseq3");
            library.open(self.directory + "/" + folder if self.game == "passion" else self.directory);
            self.libraries[game] = library;
        }
        return self.libraries[game];
    }
    def model(reference: str, skin: int = 0) -> ModelAsset {
        parts = reference.split(":", 1);
        if len(parts) != 2 { raise ValueError("Model needs a game namespace"); }
        return self.source(parts[0]).model(parts[1], skin);
    }
    def close() {
        for key in self.libraries { self.libraries[key].close(); }
        self.libraries = {};
    }
}
