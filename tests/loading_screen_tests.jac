"""Each game's loading screen: where Quake and Quake II put their plaque,
and the lines Quake III's information screen gives about the arena."""
import from engine.render.hud { loading_plaque_place }
import from games.arenas { parse_arenas, find_arena, arena_loading_lines }

test "SCR_DrawLoading centres Quake's plaque above the status bar and Quake II's in the screen" {
    # gfx/loading.lmp is 144 by 24: (320 - 144) / 2, (200 - 48 - 24) / 2.
    assert loading_plaque_place("q1", 144, 24, 320, 200, 1.0) == (88.0, 64.0);
    # At three times the size on a 1280 by 720 window.
    assert loading_plaque_place("q1", 144, 24, 1280, 720, 3.0) == (424.0, 252.0);
    # pics/loading.pcx: (viddef.width - w) / 2, (viddef.height - h) / 2.
    assert loading_plaque_place("q2", 128, 32, 640, 480, 2.0) == (192.0, 208.0);
}

test "CG_DrawInformation's lines for a local game" {
    arenas = parse_arenas(
        "{\nmap q3dm1\nlongname \"Arena Gate\"\nfraglimit 15\ntype \"ffa tourney single\"\n}\n"
            + "{\nmap q3ctf1\nlongname \"Dueling Keeps\"\ntype ctf\n}\n"
    );
    assert arena_loading_lines(find_arena(arenas, "q3dm1")) == ["Arena Gate", "Single Player", "fraglimit 15"];
    # An arena that sets neither limit is played to ten frags (G_InitBots),
    # and the screen shows the limit the match has.
    assert arena_loading_lines(find_arena(arenas, "q3ctf1")) == ["Dueling Keeps", "Free For All", "fraglimit 10"];
    # A map the arena list does not know.
    assert arena_loading_lines(find_arena(arenas, "test_bigbox")) == ["Free For All", "fraglimit 20"];
}
