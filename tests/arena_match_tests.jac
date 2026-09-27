import from games.arenas {
    parse_arenas,
    parse_bots,
    ladder,
    next_arena,
    find_arena,
    find_bot,
    postgame_medals
}
import from engine.render.arena_screens { Postgame, prop_width, postgame_score_line }
import from engine.world.arena {
    ArenaMatch,
    HasMatch,
    Competes,
    SpawnPoint,
    HasSpawn,
    MatchTick,
    ChooseSpawn,
    join_match,
    standings,
    score_rows,
    place_string,
    ordinal
}
import from engine.world.combat {
    CombatState,
    CombatTick,
    Opponent,
    HasOpponent,
    strike
}
import from engine.world.damage { Damage }
import from engine.world.world { World, Player }
import from engine.world.level { Level }
import from engine.core.savegame { snapshot, restore }
import from engine.physics.collision { CollisionMap }
import from engine.math.vec3 { Vec3 }

glob ARENAS: str = """
{
map         "q3dm0"
bots        "crash"
longname    "Introduction"
special     "Training"
fraglimit   5
type        "single"
}
// comments are ignored
{
map         "q3dm1"
bots        "ranger"
longname    "Arena Gate"
fraglimit   10
type        "single ffa tourney"
}
{
map         "q3ctf1"
longname    "Dueling Keeps"
type        "ctf"
}
{
map         "q3tourney6"
bots        "xaero"
special     "Final"
fraglimit   10
type        "single ffa tourney"
}
{
map         "q3dm2"
bots        "phobos grunt"
fraglimit   10
type        "single ffa"
}
""";

glob BOTS: str = """
{
name        Daemia
model       major/daemia
aifile      bots/daemia_c.c
}
{
name        Xaero
model       xaero
arenaLord   1
}
""";

def contest_with(names: list[str], fraglimit: int = 3) -> ArenaMatch {
    contest = ArenaMatch(fraglimit=fraglimit);
    for name in names {
        actor = Opponent(arena=True, health=100);
        contest +>:Competes:name=name:+> actor;
    }
    return contest;
}

test "arena and bot scripts follow the original ladder order and model paths" {
    arenas = parse_arenas(ARENAS);
    assert len(arenas) == 5 and arenas[1].longname == "Arena Gate";
    assert arenas[4].bots == ["phobos", "grunt"] and arenas[0].fraglimit == 5;
    order = [arena.map for arena in ladder(arenas)];
    assert order == ["q3dm0", "q3dm1", "q3dm2", "q3tourney6"];
    assert next_arena(arenas, "q3dm1") == "q3dm2";
    assert next_arena(arenas, "q3tourney6") == "";
    assert find_arena(arenas, "Q3DM1") is not None and find_arena(arenas, "x") is None;
    bots = parse_bots(BOTS);
    daemia = find_bot(bots, "daemia");
    assert daemia.model == "major" and daemia.skin == "daemia";
    assert find_bot(bots, "xaero").arena_lord and find_bot(bots, "xaero").skin == "default";
    assert find_bot(bots, "sarge").name == "Sarge" and find_bot(bots, "sarge").model == "sarge";
    assert ordinal(1) == "1st" and ordinal(3) == "3rd" and ordinal(5) == "5th";
}

test "frags follow killers, world deaths cost a frag and the limit ends the match" {
    contest = contest_with(["Ranger", "Phobos"]);
    player = Player(health=125);
    contest +>:Competes:name="You", human=True:+> player;
    actors = [contest->:Competes:->];
    ranger = actors[0];
    phobos = actors[1];
    ranger.health = 0;
    ranger.killer = player;
    first = contest spawn MatchTick(dt=0.01);
    assert first.messages == ["You fragged Ranger\n1st place with 1"];
    assert "sound/feedback/takenlead.wav" in first.cues;
    contest spawn MatchTick(dt=0.01);
    assert standings(contest)[0].frags == 1;
    phobos.health = 0;
    phobos.killer = None;
    contest spawn MatchTick(dt=0.01);
    rows = standings(contest);
    assert rows[-1].name == "Phobos" and rows[-1].frags == -1;
    player.health = 0;
    player.killer = ranger;
    lost = contest spawn MatchTick(dt=0.01);
    assert "You were fragged by Ranger" in lost.messages;
    assert "sound/feedback/tiedlead.wav" in lost.cues;
    ranger.health = 100;
    phobos.health = 100;
    player.health = 125;
    contest spawn MatchTick(dt=0.01);
    for i in range(2) {
        phobos.health = 0;
        phobos.killer = player;
        tick = contest spawn MatchTick(dt=0.01);
        phobos.health = 100;
        contest spawn MatchTick(dt=0.01);
    }
    assert contest.finished and contest.winner == "You";
    assert "sound/player/announce/youwin.wav" in tick.cues and tick.ended;
}

test "frags-left cues play once each and bot wins use their own announcement" {
    contest = contest_with(["Ranger", "Sarge"], 4);
    actors = [contest->:Competes:->];
    cues: list[str] = [];
    for i in range(4) {
        actors[1].health = 0;
        actors[1].killer = actors[0];
        cues.extend((contest spawn MatchTick(dt=0.01)).cues);
        actors[1].health = 100;
        contest spawn MatchTick(dt=0.01);
    }
    assert cues.count("sound/feedback/3_frags.wav") == 1;
    assert cues.count("sound/feedback/1_frag.wav") == 1;
    assert "sound/player/announce/ranger_wins.wav" in cues and contest.winner == "Ranger";
}

test "the warmup counts down to fight before any scoring" {
    contest = contest_with(["Ranger"]);
    contest.warmup = 4.0;
    actors = [contest->:Competes:->];
    actors[0].health = 0;
    cues: list[str] = [];
    for i in range(45) {
        cues.extend((contest spawn MatchTick(dt=0.1)).cues);
    }
    assert cues == [
        "sound/feedback/prepare.wav",
        "sound/feedback/three.wav",
        "sound/feedback/two.wav",
        "sound/feedback/one.wav",
        "sound/feedback/fight.wav"
    ];
    assert contest.warmup == 0.0 and standings(contest)[0].deaths == 1;
}

test "spawn selection prefers the furthest clear half of the spawn points" {
    world = World();
    for x in [0.0, 100.0, 1000.0, 2000.0] {
        world +>:HasSpawn:+> SpawnPoint(pos=Vec3(x=x));
    }
    for seed in range(1, 6) {
        choice = world spawn ChooseSpawn(avoid=[Vec3(x=10.0)], seed=seed);
        spot = choice.pick();
        assert spot is not None and spot.pos.x >= 1000.0;
    }
    empty = World() spawn ChooseSpawn();
    assert empty.pick() is None;
}

test "bots damage each other through the full opponent path with credit" {
    shooter = Opponent(arena=True, health=100, pos=Vec3(x=300.0));
    target = Opponent(arena=True, health=20);
    dealt = strike(target, 50, shooter);
    assert dealt == 20 and target.health == 0 and target.killer is shooter;
    assert target.respawn_wait == 1.7 and target.pose_name == "death";
    player = Player(health=100);
    assert strike(player, 30, shooter) == 30 and player.health == 70;
    assert player.killer is None;
    strike(player, 100, shooter);
    assert player.killer is shooter;
}

test "arena bots pick the nearest visible competitor over a distant player" {
    world = World();
    bot = Opponent(arena=True, health=100, pos=Vec3(z=22.0), eye_height=22.0);
    rival = Opponent(arena=True, health=100, pos=Vec3(x=200.0, z=22.0), eye_height=22.0);
    world +>:HasOpponent:+> bot;
    world +>:HasOpponent:+> rival;
    player = Player(health=100, pos=Vec3(x=1200.0, z=22.0));
    world spawn CombatTick(
        player=player, collision=CollisionMap(), state=CombatState(), dt=0.2
    );
    assert bot.foe is rival and rival.foe is bot;
    assert bot.last_seen.x == 200.0;
    player.health = 0;
    rival.health = 0;
    world spawn CombatTick(
        player=player,
        collision=CollisionMap(),
        state=CombatState(),
        dt=0.2,
        arena_live=True
    );
    assert bot.foe is None;
}

test "players join once with spawn health and match state survives saves" {
    world = World();
    contest = ArenaMatch(fraglimit=7, warmup=2.0);
    world +>:HasMatch:+> contest;
    bot = Opponent(arena=True, health=100);
    world +>:HasOpponent:+> bot;
    contest +>:Competes:name="Ranger":+> bot;
    player = Player();
    join_match(world, player);
    join_match(world, player);
    assert player.health == 125 and len([contest->:Competes:->]) == 2;
    scores = [edge contest->:Competes:->];
    scores[0].frags = 4;
    scores[1].deaths = 2;
    level = Level();
    level.name = "test";
    data = snapshot(world, level, player, CombatState());
    scores[0].frags = 0;
    scores[1].deaths = 0;
    contest.warmup = 0.0;
    restore(world, level, player, CombatState(), data);
    assert scores[0].frags == 4 and scores[1].deaths == 2 and contest.warmup == 2.0;
    assert contest.fraglimit == 7;
}

test "quick frags, gauntlet frags and flawless wins earn the original awards" {
    contest = contest_with(["Ranger", "Phobos"]);
    contest.fraglimit = 3;
    player = Player(health=125);
    contest +>:Competes:name="You", human=True:+> player;
    actors = [contest->:Competes:->];
    ranger = actors[0];
    phobos = actors[1];
    ranger.health = 0;
    ranger.killer = player;
    first = contest spawn MatchTick(dt=0.5);
    assert "sound/feedback/excellent.wav" not in first.cues;
    phobos.health = 0;
    phobos.killer = player;
    phobos.death_means = "gauntlet";
    second = contest spawn MatchTick(dt=0.5);
    assert "sound/feedback/excellent.wav" in second.cues;
    assert "sound/feedback/humiliation.wav" in second.cues;
    rows = [edge contest->:Competes:->];
    assert rows[2].excellent == 1 and rows[2].humiliation == 1;
    ranger.health = 100;
    contest spawn MatchTick(dt=5.0);
    ranger.health = 0;
    ranger.killer = player;
    ranger.death_means = "";
    last = contest spawn MatchTick(dt=0.5);
    # Three frags and no deaths: the match is won Perfect, but not Excellent.
    assert last.ended and "sound/player/announce/youwin.wav" in last.cues;
    assert "sound/feedback/perfect.wav" in last.cues;
    assert "sound/feedback/excellent.wav" not in last.cues;
}

test "the scoreboard ranks by score and marks shared places" {
    contest = contest_with(["Ranger", "Phobos", "Visor"]);
    player = Player(health=125);
    contest +>:Competes:name="You", human=True:+> player;
    scores = [edge contest->:Competes:->];
    scores[0].frags = 4;
    scores[1].frags = 7;
    scores[2].frags = 4;
    scores[3].frags = 2;
    scores[0].excellent = 2;
    rows = score_rows(contest);
    assert [row.name for row in rows] == ["Phobos", "Ranger", "Visor", "You"];
    assert [row.rank for row in rows] == [0, 1, 1, 3];
    assert not rows[0].tied and rows[1].tied and rows[2].tied and not rows[3].tied;
    assert rows[1].excellent == 2 and rows[3].human and rows[3].actor is player;
    assert place_string(1, True) == "Tied for 2nd" and place_string(3, False) == "4th";
    assert postgame_score_line(1, True, "Ranger", 4) == "(tie) #2: Ranger            4";
}

test "the postgame awards accuracy, counts, career frags and perfect" {
    none = postgame_medals(49, 0, 0, 0, 12, False, 10);
    assert not none;
    medals = postgame_medals(67, 2, 1, 3, 20, True, 185);
    assert [medal.kind for medal in medals] == ["accuracy", "impressive", "excellent", "gauntlet", "frags", "perfect"];
    assert [medal.amount for medal in medals] == [67, 2, 1, 3, 200, 1];
    # Frags are awarded as the career total passes each hundred.
    assert not [medal for medal in postgame_medals(0, 0, 0, 0, 14, False, 185) if medal.kind == "frags"];
}

test "the postgame shows the podium, presents each award, then the buttons" {
    board = Postgame(ignore_until=1.5, medals=["accuracy", "excellent"], amounts=[60, 2], winner_sound="sound/player/announce/youwin.wav");
    # Keys are ignored for the first moment and a half.
    assert board.key(1.0, "enter") == "" and board.phase == 1;
    assert board.update(1.2) == ["sound/player/announce/youwin.wav"];
    assert board.update(5.0) == ["sound/feedback/accuracy.wav"] and board.phase == 2;
    assert board.update(7.1) == ["sound/feedback/excellent_a.wav"];
    # At least five seconds on the awards, then the buttons.
    board.update(9.5);
    assert board.phase == 2;
    board.update(10.1);
    assert board.phase == 3 and board.focus == 2;
    assert board.key(10.2, "enter") == "";
    assert board.key(10.5, "enter") == "next";
    board.key(10.6, "left");
    assert board.key(10.7, "enter") == "replay";
    board.key(10.8, "left");
    board.key(10.9, "left");
    assert board.key(11.0, "enter") == "menu";
    # A key skips the podium, then the awards.
    skipped = Postgame(medals=["frags"], amounts=[100]);
    skipped.key(0.5, "any");
    assert skipped.phase == 2;
    skipped.key(1.0, "any");
    assert skipped.phase == 3;
    assert prop_width("A") == 18 and prop_width("AB") == 39 and prop_width(" ") == 8;
}
