"""Original archive models and attack definitions for the supported campaign roster."""
import from games.enemies { enemy_rule }
import from engine.assets.library { AssetLibrary }
import from engine.core.menu { game_directory }
with entry {
    for game in ["q1", "q2"] {
        library = AssetLibrary(game=game);
        library.open(game_directory(game));
        names = [
            "monster_army",
            "monster_dog",
            "monster_knight",
            "monster_enforcer",
            "monster_ogre"
        ]
            if game == "q1"
            else [
                "monster_soldier_light",
                "monster_soldier",
                "monster_soldier_ss",
                "monster_infantry"
            ];
        for name in names {
            rule = enemy_rule(game, name);
            assert rule is not None;
            loaded = library.model(rule.model, skin=rule.skin);
            assert loaded.model.surfaces and loaded.skins;
            assert loaded.model.surfaces[0].frames;
            print("Enemy asset passed:", game, name, rule.health, rule.skin);
        }
        library.close();
    }
}
