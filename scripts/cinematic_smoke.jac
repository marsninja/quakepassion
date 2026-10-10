"""Every original film through the one cinematic player: Quake III's RoQ
films from the pk3s and Quake II's .cin films from baseq2/video.

Each film is decoded to its end with the player's own clock stepped a
picture at a time. The report gives its size, pictures, length and decode
cost; chosen pictures are drawn through the player's screen path and
saved to .jac/screenshots/films/<film>_<picture>.png (tier1_roq_45.png).

    jac build scripts/cinematic_smoke.jac --native -o .jac/cinematic-smoke
    DYLD_LIBRARY_PATH=vendor .jac/cinematic-smoke

QP_FILMS=intro.RoQ,eou1_.cin narrows the run; QP_FILM_SHOTS=30,200 chooses
the pictures saved (counted from 1).

QP_FILM_FLOW=1 then runs Quake III's films through the game loop on the
training arena: the start-up chain (the id logo going on to the introduction
through `nextmap`, a key ending each), and a won match whose postgame plays
tier1.RoQ once and then opens the level menu. This part records ladder
progress, so give it a disposable HOME:

    HOME=/tmp/qp-films QP_GAME=q3 QP_ASSETS=$HOME/quake-assets/baseq3 \
        QP_FILMS=idlogo.RoQ QP_FILM_FLOW=1 DYLD_LIBRARY_PATH=vendor .jac/cinematic-smoke
"""
import os;
import time;
import zlib;
import from engine.assets.library { AssetLibrary }
import from engine.audio.feedback { Feedback }
import from engine.core.cinematic { CinematicPlayer }
import from engine.core.menu { game_directory }
import from engine.render.renderer { Renderer }
import from engine.core.app { App }
import from engine.core.clock { Clock }
import from engine.world.world { World, Player }
import from engine.world.arena { ArenaMatch, Competes, match_of }
import from engine.input.input { Intent }

glob SMOKE_FILMS: list[str] = [
    "idlogo.RoQ", "intro.RoQ", "tier1.RoQ", "tier2.RoQ", "tier3.RoQ", "tier4.RoQ",
    "tier5.RoQ", "tier6.RoQ", "tier7.RoQ", "end.RoQ", "ntro.cin", "eou1_.cin", "end.cin"
];

def draw_picture(renderer: Renderer, player: CinematicPlayer, path: str) {
    # Two frames, so the capture reads a presented picture.
    for attempt in range(2) {
        renderer.begin_screen();
        player.draw(renderer.width, renderer.height);
        renderer.end_frame();
    }
    renderer.screenshot(path);
}

with entry {
    os.makedirs(".jac/screenshots/films", exist_ok=True);
    wanted = [name for name in os.getenv("QP_FILMS", "").split(",") if name];
    shots = [int(text) for text in os.getenv("QP_FILM_SHOTS", "1,45,150,300").split(",") if text];
    renderer = Renderer();
    renderer.open_window();
    audio = Feedback();
    player = CinematicPlayer();
    for name in (wanted if wanted else SMOKE_FILMS) {
        game = "q3" if name.lower().endswith(".roq") else "q2";
        library = AssetLibrary(game=game);
        library.open(game_directory(game));
        if not library.exists("video/" + name) {
            print("FILM", name, "missing");
            library.close();
            continue;
        }
        data = library.read("video/" + name);
        library.close();
        started = time.perf_counter();
        player.play(name, data, audio);
        film = player.film;
        assert player.active and film is not None , name;
        step = 1.0 / float(film.frame_rate);
        pictures = 0;
        sum_all = 0;
        shown = -1;
        finished = False;
        while not finished {
            if player.frame != shown {
                shown = player.frame;
                pictures += 1;
                sum_all = zlib.crc32(player.pic, sum_all);
                if pictures in shots {
                    stem = name.lower().replace(".", "_");
                    draw_picture(renderer, player, ".jac/screenshots/films/" + stem + "_" + str(pictures) + ".png");
                }
            }
            # Just under a picture's time, so no step ever reads two.
            finished = player.advance(step * 0.999, False, audio) or player.idle;
        }
        seconds = time.perf_counter() - started;
        print(
            "FILM", name, str(player.width) + "x" + str(player.height), "rate", film.frame_rate,
            "pictures read", film.frame, "shown", pictures, "seconds", round(float(film.frame) / float(film.frame_rate), 2),
            "held" if player.idle else "ended", "crc", sum_all,
            "decode ms/picture", round(seconds * 1000.0 / float(max(1, film.frame)), 3)
        );
        player.stop(audio);
    }
    player.close(audio);
    if os.getenv("QP_FILM_FLOW", "") != "" {
        film_flow(renderer);
    }
    renderer.close();
    print("CINEMATIC SMOKE PASSED");
}

"""Step the game `frames` times at 30 frames a second."""
def run_frames(app: App, frames: int) {
    for frame in range(frames) {
        assert app.step();
    }
}

"""A key press as the film sees it: let go, then held for a frame."""
def press_key(app: App) {
    app.scripted = Intent();
    run_frames(app, 1);
    app.scripted = Intent(fire=True);
    run_frames(app, 1);
    app.scripted = Intent();
}

def film_flow(renderer: Renderer) {
    app = App(world=World(), player=Player(), renderer=renderer, clock=Clock(), smoke=True);
    app.host.overlay.assign("0");
    app.load_destination("q3", "q3dm0");
    app.smoke = False;
    app.walking = True;
    app.fixed_dt = 1.0 / 30.0;
    # Com_Init: the id logo, then the introduction through nextmap.
    app.host.nextmap.assign("cinematic intro.RoQ");
    app.shell.add_text("cinematic idlogo.RoQ");
    run_frames(app, 20);
    assert app.cinematic.active and app.cinematic.name == "idlogo.RoQ" , app.cinematic.name;
    assert app.cinematic.frame >= 19 , str(app.cinematic.frame);
    renderer.screenshot(".jac/screenshots/films/flow_idlogo.png");
    press_key(app);
    assert app.cinematic.active and app.cinematic.name == "intro.RoQ" , app.cinematic.name;
    assert app.host.nextmap.text == "";
    run_frames(app, 400);
    renderer.screenshot(".jac/screenshots/films/flow_intro.png");
    press_key(app);
    assert not app.cinematic.active and not app.menu.opened;
    print("FILM FLOW start-up: idlogo.RoQ -> intro.RoQ -> the level");
    # A won training match: the postgame's third phase plays tier1.RoQ once.
    contest = match_of(app.world);
    assert contest is not None;
    contest.warmup = 0.0;
    for score in [edge contest->:Competes:->] {
        if score.human {
            score.frags = contest.fraglimit;
        }
    }
    contest.finished = True;
    app.arena_progress.load();
    app.arena_progress.record("q3dm0", 1);
    app.begin_podium(contest);
    board = app.postgame;
    assert board is not None and board.won and board.tier == 0 , "the training arena completes tier 0";
    # Past the podium and the awards.
    for phase in range(2) {
        app.postgame_clock += 60.0;
        run_frames(app, 1);
    }
    run_frames(app, 1);
    assert app.cinematic.active and app.cinematic.name == "tier1.RoQ" , app.cinematic.name;
    assert "tier1" in app.host.videos.text and app.host.nextmap.text == "levelselect";
    run_frames(app, 150);
    renderer.screenshot(".jac/screenshots/films/flow_tier1.png");
    press_key(app);
    assert not app.cinematic.active and app.menu.opened , "the level menu follows a tier film";
    assert app.menu.maps[app.menu.selected] == "q3dm1" , app.menu.maps[app.menu.selected];
    app.menu.opened = False;
    run_frames(app, 5);
    assert not app.cinematic.active , "a tier's film plays once";
    print("FILM FLOW postgame: tier1.RoQ once, then the level menu on", app.menu.maps[app.menu.selected]);
    # The final arena's win plays end.RoQ, which holds its last picture.
    board.tier = board.last_tier;
    run_frames(app, 2);
    assert app.cinematic.active and app.cinematic.name == "end.RoQ" , app.cinematic.name;
    film = app.cinematic.film;
    assert film is not None and film.holds;
    print("FILM FLOW final: end.RoQ, held at its end");
    press_key(app);
    assert not app.cinematic.active and app.menu.opened;
}
