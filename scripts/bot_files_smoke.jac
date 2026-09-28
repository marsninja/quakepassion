"""The original bot files through botlib's precompiler: every bot's character
with its item and weapon weights and chats, items.c, weapons.c and rnd.c.
Prints what each bot would fight with and go for with a fresh spawn's
inventory, and the lightning gun's weight either side of 768 units."""
import from engine.core.menu { game_directory }
import from engine.assets.library { AssetLibrary }
import from engine.world.bot_weights {
    INVENTORY_HEALTH,
    INVENTORY_ARMOR,
    INVENTORY_MACHINEGUN,
    INVENTORY_BULLETS,
    INVENTORY_LIGHTNING,
    INVENTORY_LIGHTNINGAMMO,
    INVENTORY_ROCKETLAUNCHER,
    INVENTORY_ROCKETS,
    INVENTORY_GAUNTLET,
    ENEMY_HORIZONTAL_DIST,
    BOT_INVENTORY_SIZE,
    best_fight_weapon
}
import from engine.formats.botconfig { WeightDice }
import from games.botfiles { BotFiles, load_bot_character }
import from games.arenas { load_bots }

with entry {
    library = AssetLibrary(game="q3");
    library.open(game_directory("q3"));
    files = BotFiles(library=library);
    items = files.item_config();
    weapons = files.weapon_names();
    randoms = files.random_strings();
    print("items " + str(len(items)) + " weapons " + str(weapons) + " random strings " + str(len(randoms)));
    assert len(items) > 30 and weapons[5] == "Rocket Launcher";
    dice = WeightDice(state=7);
    for bot in load_bots(library) {
        mind = load_bot_character(files, bot.aifile, 3.0);
        fresh: list[int] = [0 for i in range(BOT_INVENTORY_SIZE)];
        fresh[INVENTORY_HEALTH] = 125;
        fresh[INVENTORY_GAUNTLET] = 1;
        fresh[INVENTORY_MACHINEGUN] = 1;
        fresh[INVENTORY_BULLETS] = 100;
        armed: list[int] = list(fresh);
        armed[INVENTORY_ROCKETLAUNCHER] = 1;
        armed[INVENTORY_ROCKETS] = 10;
        armed[INVENTORY_LIGHTNING] = 1;
        armed[INVENTORY_LIGHTNINGAMMO] = 100;
        armed[ENEMY_HORIZONTAL_DIST] = 500;
        near = best_fight_weapon(mind.weapon_weights, mind.weapon_numbers, armed);
        armed[ENEMY_HORIZONTAL_DIST] = 1000;
        far = best_fight_weapon(mind.weapon_weights, mind.weapon_numbers, armed);
        lightning = mind.weapon_weights.find("Lightning Gun");
        beyond = mind.weapon_weights.weight(armed, lightning);
        wants: list[str] = [];
        for info in items {
            number = mind.item_numbers.get(info.classname, -1);
            if number >= 0 {
                weight = mind.item_weights.undecided(fresh, number, dice);
                wants.append(info.classname + "=" + str(int(weight)));
            }
        }
        print(
            bot.name + " fights with " + str(best_fight_weapon(mind.weapon_weights, mind.weapon_numbers, fresh))
                + " armed " + str(near) + " far " + str(far) + " lightning beyond 768 " + str(beyond)
                + " chat types " + str(len(mind.chats)) + " weights " + str(len(wants)) + " " + " ".join(wants[0:6])
        );
        assert mind.weapon_numbers and mind.item_numbers and mind.chats;
        # $evalint(W_LIGHTNING*0.1) truncates 0.1 to an integer first.
        assert beyond == 0.0;
    }
    library.close();
}
