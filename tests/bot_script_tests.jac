"""botlib's precompiler and configs: bot files as botlib reads them."""
import from engine.formats.botscript { precompile, script_includes, lex_script, TT_STRING, TT_NUMBER, TT_NAME }
import from engine.formats.botconfig {
    WeightDice,
    read_weight_config,
    read_item_config,
    read_weapon_names,
    read_initial_chat,
    read_random_strings,
    MAX_INVENTORYVALUE
}
import from engine.world.bot_chat { BotChatState, construct_chat, choose_chat, initial_chat, enter_chat, easy_client_name }
import from games.botfiles { BotFiles, character_from }

# fw_items.c's balance macros, over a character's #defines (sarge_i.c style).
glob ITEM_FILES: dict[str, str] = {
    "inv.h": "#define INVENTORY_ARMOR 1\n#define INVENTORY_HEALTH 29\n#define INVENTORY_SCOUT 41\n",
    "fw_items.c": """
#define BR_ARMOR 30
#define MZ(value)				(value) < 0 ? 0 : (value)
#define ARMOR_SCALE(v)			balance($evalfloat(MZ(FS_ARMOR*v)), $evalfloat(MZ(FS_ARMOR*v-BR_ARMOR)), $evalfloat(MZ(FS_ARMOR*v+BR_ARMOR)))
#ifndef W_KAMIKAZE
#define W_KAMIKAZE			200
#endif
weight "item_armor_shard"
{
	switch(INVENTORY_SCOUT)
	{
		case 1:
		{
			switch(INVENTORY_ARMOR)
			{
				case 10: return ARMOR_SCALE(20);
				case 100: return ARMOR_SCALE(15);
				default: return ARMOR_SCALE(1);
			} //end switch
		} //end case
		default: return 0;
	} //end switch
} //end weight
weight "item_kamikaze"
{
	return W_KAMIKAZE;
}
""",
    "bots/sample_i.c": "#include \"inv.h\"\n#define FS_ARMOR 2\n#define W_KAMIKAZE 50\n#include \"fw_items.c\"\n"
};

test "the precompiler expands macros, evaluates $eval and follows includes" {
    assert script_includes(ITEM_FILES["bots/sample_i.c"]) == ["inv.h", "fw_items.c"];
    tokens = precompile("bots/sample_i.c", ITEM_FILES);
    texts = [token.text for token in tokens];
    # ARMOR_SCALE(20) with FS_ARMOR 2: balance(40, 10, 70); MZ keeps 0 for
    # ARMOR_SCALE(1)'s 2 - 30.
    at = texts.index("balance");
    assert [tokens[at + 2].number, tokens[at + 4].number, tokens[at + 6].number] == [40.0, 10.0, 70.0];
    last = len(texts) - 1 - texts[::-1].index("balance");
    assert tokens[last + 4].number == 0.0 and tokens[last + 6].number == 32.0;
    # The character's W_KAMIKAZE came first, so fw_items.c keeps it.
    assert "50" in texts and "200" not in texts;
    # A float's integer value is truncated before $evalint multiplies.
    lightning = precompile("w.c", {"w.c": "#define W_LIGHTNING 80\nx $evalint(W_LIGHTNING*0.1) y $evalfloat(W_LIGHTNING*0.1)"});
    assert lightning[1].whole == 0 and abs(lightning[3].number - 8.0) < 0.0001;
    # Strings join across white space; names, numbers and strings keep their kinds.
    lexed = lex_script("\"a\" \"b\" name 12 3.5");
    assert lexed[0].kind == TT_STRING and lexed[0].text == "ab";
    assert lexed[1].kind == TT_NAME and lexed[2].kind == TT_NUMBER and lexed[2].integer and not lexed[3].integer;
}

test "fuzzy weights take the case above the inventory and draw balanced weights" {
    config = read_weight_config(precompile("bots/sample_i.c", ITEM_FILES));
    shard = config.find("item_armor_shard");
    assert shard == 0 and config.find("item_kamikaze") == 1 and config.find("nothing") == -1;
    inventory = [0 for i in range(256)];
    # No armor: below case 10.
    assert config.weight(inventory, shard) == 40.0;
    # 10 up to 100 armor falls in case 100 (botlib's integer blend scale is 0).
    inventory[1] = 50;
    assert config.weight(inventory, shard) == 30.0;
    inventory[1] = 150;
    assert config.weight(inventory, shard) == 2.0;
    # FuzzyWeightUndecided draws within balance(30, 0, 60).
    inventory[1] = 50;
    dice = WeightDice(state=11);
    seen = [config.undecided(inventory, shard, dice) for i in range(40)];
    assert min(seen) >= 0.0 and max(seen) <= 60.0 and len(set(seen)) > 10;
    # The scout's switch falls to its default of 0 with a scout.
    inventory[41] = 1;
    assert config.weight(inventory, shard) == 0.0;
    assert config.weight(inventory, 1) == 50.0;
    # A switch without a default gets botlib's zero one.
    bare = read_weight_config(precompile("b.c", {"b.c": "weight \"x\" { switch(3) { case 5: return 7; } }"}));
    assert bare.switches[0][1].value == MAX_INVENTORYVALUE and bare.weight(inventory, 0) == 7.0;
}

test "item and weapon configs name what bots know" {
    items = read_item_config(precompile("items.c", {
        "items.c": "iteminfo \"item_armor_shard\"\n{\n\tname \"Armor Shard\"\n\tmodel \"models/powerups/armor/shard.md3\"\n\tindex 1\n\trespawntime 20\n\tmins {-15,-15,-15}\n\tmaxs {15,15,15}\n}\n"
    }));
    assert len(items) == 1 and items[0].classname == "item_armor_shard" and items[0].respawntime == 20.0;
    assert items[0].mins.x == -15.0 and items[0].maxs.z == 15.0;
    names = read_weapon_names(precompile("weapons.c", {
        "weapons.c": "#define WEAPONINDEX_RAILGUN 7\nprojectileinfo { name \"slug\" damage 100 }\nweaponinfo\n{\n\tname \"Railgun\"\n\tnumber WEAPONINDEX_RAILGUN\n\trecoil {0, 0, 0}\n}\n"
    }));
    assert names == {7: "Railgun"};
}

glob CHAT_FILES: dict[str, str] = {
    "rnd.c": "TAUNT = {\n\t\"take that, \", 0, \"!\";\n}\nWORD = {\n\t\"~hey\";\n}\n",
    "bots/sample_t.c": """
chat "other" { type "kill_insult" { "no"; } }
chat "sample"
{
	type "kill_insult"
	{
		"Down you go, ", 0, ".";
		WORD, " ", TAUNT;
	} //end type
	type "game_enter" { "Hello ", 1; }
}
"""
};

test "chats fill their variables and random strings and say each line once a while" {
    chats = read_initial_chat(precompile("bots/sample_t.c", CHAT_FILES), "Sample");
    randoms = read_random_strings(precompile("rnd.c", CHAT_FILES));
    assert sorted(chats.keys()) == ["game_enter", "kill_insult"] and len(chats["kill_insult"]) == 2;
    dice = WeightDice(state=5);
    assert construct_chat(chats["kill_insult"][0], ["sarge"], randoms, dice) == "Down you go, sarge.";
    # Random strings nest and fill the same variables.
    assert construct_chat(chats["kill_insult"][1], ["sarge"], randoms, dice) == "~hey take that, sarge!";
    # BotChooseInitialChatMessage avoids lines said in the last 20 seconds.
    first = choose_chat(chats, "kill_insult", 0.0, dice);
    second = choose_chat(chats, "kill_insult", 1.0, dice);
    assert first is not None and second is not None and first is not second;
    # BotEnterChat removes the tildes and says it with the bot's name.
    state = BotChatState();
    assert initial_chat(chats, randoms, state, "game_enter", ["", "keel"], 0.0, dice);
    assert enter_chat(state, "Sample") == "Sample^7: ^2Hello keel" and state.message == "";
    assert not initial_chat(chats, randoms, state, "death_rail", [], 0.0, dice);
    # EasyClientName: no spaces, clans, Mr or capitals.
    assert easy_client_name("Mr [ID] Big ^1Boss") == "bigboss";
}

test "a character loads its weights and chats from the bot files" {
    files = BotFiles(texts={
        "bots/sample_c.c": "skill 1\n{\n\tCHARACTERISTIC_NAME \"Sample\"\n\tCHARACTERISTIC_ITEMWEIGHTS \"bots/sample_i.c\"\n\tCHARACTERISTIC_WEAPONWEIGHTS \"bots/sample_w.c\"\n\tCHARACTERISTIC_CHAT_FILE \"bots/sample_t.c\"\n\tCHARACTERISTIC_CHAT_NAME \"sample\"\n\tCHARACTERISTIC_CHAT_KILL 0.4\n\tCHARACTERISTIC_WEAPONJUMPING 0.75\n}\n",
        "bots/sample_w.c": "weight \"Railgun\" { switch(10) { case 1: return 0; default: return 90; } }\n",
        "items.c": "iteminfo \"item_armor_shard\" { name \"Armor Shard\" respawntime 20 }\niteminfo \"item_quad\" { name \"Quad\" }\n",
        "weapons.c": "weaponinfo { name \"Railgun\" number 7 }\n",
        "inv.h": ITEM_FILES["inv.h"],
        "fw_items.c": ITEM_FILES["fw_items.c"],
        "bots/sample_i.c": ITEM_FILES["bots/sample_i.c"],
        "bots/sample_t.c": CHAT_FILES["bots/sample_t.c"],
        "rnd.c": CHAT_FILES["rnd.c"]
    });
    mind = character_from(files.text("bots/sample_c.c"), "", 1.0, files);
    assert mind.name == "Sample" and mind.chat_kill == 0.4 and mind.weapon_jumping == 0.75;
    assert mind.weapon_numbers == {7: 0} and mind.item_numbers == {"item_armor_shard": 0, "item_quad": -1};
    assert "kill_insult" in mind.chats and "TAUNT" in mind.random_strings;
}
