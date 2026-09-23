import from games.arenas {
    parse_arenas,
    parse_bots,
    ladder,
    next_arena,
    find_arena,
    find_bot
}
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
    assert first.messages == ["You fragged Ranger"];
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
