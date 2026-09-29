"""Q3 bot AI after ai_dmnet.c and ai_dmq3.c BotDeathmatchAI. The AI's
states are nodes of a graph, `AINode`s under the world's `BotBrain`, linked by
`Leads` edges wherever ai_dmnet.c switches from one to another: seek a long
term goal, seek a nearby goal, battle (fight, chase, retreat, nearby goal),
stand (while typing a chat line) and respawn. Every think (10 Hz,
bot_thinktime) a `BotThink` walker enters the bot's current node and runs it;
a node that switches walks on to the next and runs it at once, as AINode_*
returning qfalse does, up to MAX_NODESWITCHES.

Before the nodes run, the think updates the bot's inventory for its fuzzy
weights (BotUpdateInventory) and reads the obituaries every client hears
(BotCheckSnapshot). The nodes pick goals (be_ai_goal.c), weapons, aim and
attack moves, and chat (ai_chat.c). What they decide is handed to the body:
the goal to move to (the combat tick routes to it over the AAS), whether to
fight in place, where to look and when to fire (BotTactics)."""
import math;
import from .world { World, Player, Actor }
import from .combat { Opponent, HasOpponent, CombatState, WEAPON_SWITCH_TIME }
import from .weapons { WeaponRule }
import from .arena { ArenaMatch, Competes, match_of, competitor_name }
import from .bot_character { BotCharacter, BotState, entity_visible, bot_travel_flags, wants_to_retreat, wants_to_chase }
import from .bot_tactics { aim_point, attack_move, choose_weapon, rule_for, foe_height, armed_with, act_bot }
import from .bot_weights { bot_inventory, battle_inventory, INVENTORY_HEALTH }
import from .bot_goals {
    BotItems,
    BotGoal,
    UpdateLevelItems,
    bot_items,
    choose_item_goal,
    reached_goal,
    touching_goal,
    air_goal
}
import from .bot_chat {
    BotChatState,
    TIME_BETWEENCHATTING,
    initial_chat,
    enter_chat,
    chat_time,
    easy_client_name,
    weapon_name_for_means,
    random_weapon_name
}
import from .bot_routes { NavMesh, HasNavMesh }
import from .level { Level }
import from .powerups { empowered }
import from ..formats.aas { TFL_DEFAULT }
import from ..physics.collision { CollisionMap }
import from ..math.vec3 { Vec3 }

# ai_main.c bot_thinktime and ai_dmnet.c MAX_NODESWITCHES.
glob BOT_THINK_TIME: float = 0.1,
    MAX_NODESWITCHES: int = 50;

"""A state of the bot AI (an ai_dmnet.c AINode_*)."""
node AINode {
    has name: str = "";
}

node SeekLongTermGoal(AINode) {}
node SeekNearbyGoal(AINode) {}
node BattleFight(AINode) {}
node BattleChase(AINode) {}
node BattleRetreat(AINode) {}
node BattleNearbyGoal(AINode) {}
node Stand(AINode) {}
node Respawn(AINode) {}

"""A switch ai_dmnet.c makes from one node to another."""
edge Leads: AINode --> AINode {}

"""The AI's state graph, one per world, shared by every bot."""
node BotBrain {
    has nodes: dict[str, AINode] = {};
}

edge HasBotBrain: World --> BotBrain {}
edge HasAINode: BotBrain --> AINode {}

"""The ai_dmnet.c state graph: its nodes and the switches between them."""
def build_bot_brain() -> BotBrain {
    brain = BotBrain();
    made: list[AINode] = [
        SeekLongTermGoal(name="seek_ltg"),
        SeekNearbyGoal(name="seek_nbg"),
        BattleFight(name="battle_fight"),
        BattleChase(name="battle_chase"),
        BattleRetreat(name="battle_retreat"),
        BattleNearbyGoal(name="battle_nbg"),
        Stand(name="stand"),
        Respawn(name="respawn")
    ];
    for state in made {
        brain.nodes[state.name] = state;
        brain +>:HasAINode:+> state;
    }
    links: dict[str, list[str]] = {
        "seek_ltg": ["stand", "battle_retreat", "battle_fight", "seek_nbg"],
        "seek_nbg": ["seek_ltg", "battle_nbg", "battle_fight"],
        "battle_fight": ["seek_ltg", "stand", "battle_chase", "battle_retreat"],
        "battle_chase": ["seek_ltg", "battle_fight", "battle_nbg", "battle_retreat"],
        "battle_retreat": ["seek_ltg", "battle_chase", "battle_fight", "battle_nbg"],
        "battle_nbg": ["seek_nbg", "battle_retreat", "battle_fight"],
        "stand": ["battle_fight", "seek_ltg"],
        "respawn": ["seek_ltg"]
    };
    for (name, targets) in links.items() {
        # A dead bot goes to respawn from any node (AIEnter_Respawn).
        if name != "respawn" {
            targets.append("respawn");
        }
        for target in targets {
            brain.nodes[name] +>:Leads:+> brain.nodes[target];
        }
    }
    return brain;
}

def bot_brain(world: World) -> BotBrain {
    found = [world->:HasBotBrain:->][?:BotBrain];
    if found {
        return found[0];
    }
    brain = build_bot_brain();
    world +>:HasBotBrain:+> brain;
    return brain;
}

"""One think of one bot (BotDeathmatchAI's node loop): enters the bot's
current node and follows its switches."""
walker BotThink {
    has bot: Opponent,
        mind: BotCharacter,
        memory: BotState,
        collision: CollisionMap,
        rules: list[WeaponRule],
        now: float,
        human: Player,
        state: CombatState,
        mesh: NavMesh | None = None,
        items: BotItems | None = None,
        contest: ArenaMatch | None = None,
        map_name: str = "",
        level: Level | None = None,
        intermission: bool = False,
        switches: int = 0;

    can start with BotBrain entry {
        visit [here.nodes.get(self.memory.ainode, here.nodes["seek_ltg"])];
    }

    # ---- node switching -------------------------------------------------

    """Switch to the node `name` (its AIEnter_* bookkeeping) and return it to
    visit when it runs this think too (`run`, AINode_* returning qfalse)."""
    def enter(current: AINode, name: str, run: bool = True) -> list[AINode] {
        memory = self.memory;
        memory.ainode = name;
        memory.battle = name[len("battle_"):] if name.startswith("battle_") else "";
        if name == "stand" {
            memory.stand_find_enemy_time = self.now + 1.0;
        } elif name == "battle_chase" {
            memory.chase_time = self.now;
        } elif name == "respawn" {
            self.enter_respawn();
        }
        if name != "battle_fight" {
            memory.suicidal = False;
        }
        self.switches += 1;
        if not run or self.switches >= MAX_NODESWITCHES {
            return [];
        }
        return [target for target in [current->:Leads:->][?:AINode] if target.name == name];
    }

    """AIEnter_Respawn: the goals are forgotten and the bot may say something
    about its death, respawning once it has (or in 1-2 seconds)."""
    def enter_respawn() {
        memory = self.memory;
        memory.goals.empty();
        memory.goals.reset_avoid();
        memory.move_goal = None;
        if self.chat_death() {
            memory.respawn_time = self.now + chat_time();
            memory.respawn_chat_time = self.now;
        } else {
            memory.respawn_time = self.now + 1.0 + self.random();
            memory.respawn_chat_time = 0.0;
        }
        memory.respawn_waiting = False;
        # The game lets a player respawn 1.7 s after death at the soonest; the
        # bot respawns once it is done (EA_Respawn in AINode_Respawn).
        memory.respawn_minimum = self.now + self.bot.respawn_wait;
        self.bot.respawn_wait = 1000.0;
    }

    def random() -> float {
        return self.memory.dice.random();
    }

    # ---- what the nodes ask about --------------------------------------

    def dead() -> bool {
        return self.bot.health <= 0;
    }

    """BotEntityVisible from the bot's eye to another player (all round)."""
    def sees(other: Player) -> bool {
        return entity_visible(self.collision, self.bot.pos, other.pos.sub(Vec3(z=foe_height(other, self.collision))));
    }

    """The enemy still in sight: checked once a think."""
    def enemy_visible() -> bool {
        enemy = self.memory.enemy;
        if enemy is None or enemy.health <= 0 {
            self.memory.sight = False;
            return False;
        }
        self.memory.sight = self.sees(enemy);
        self.memory.sight_target = enemy;
        return self.memory.sight;
    }

    """ai_dmq3.c BotFindEnemy: the enemy the combat tick's look found (in the
    bot's view, within its alertness' reach, only closer than `current`)
    becomes the bot's, with its reaction time running from now (or two
    seconds ago when it replaces a living enemy)."""
    def find_enemy(current: Player | None) -> bool {
        foe = self.bot.foe;
        if foe is None or foe.health <= 0 or foe is current or not self.sees(foe) {
            return False;
        }
        memory = self.memory;
        memory.enemy = foe;
        memory.sight = True;
        memory.sight_target = foe;
        self.bot.enemy_sight = 2.0 if current is not None else 0.0;
        memory.enemy_suicide = False;
        memory.enemy_death_time = 0.0;
        memory.enemy_visible_time = self.now;
        return True;
    }

    """Remember where the enemy is when its spot is in an AAS area with
    reachabilities (lastenemyorigin, lastenemyareanum)."""
    def note_enemy_spot() {
        enemy = self.memory.enemy;
        mesh = self.mesh;
        if enemy is None or mesh is None {
            return;
        }
        origin = enemy.pos.sub(Vec3(z=foe_height(enemy, self.collision)));
        area = mesh.locate(origin);
        if area > 0 and mesh.aas.areas[area].reach_count > 0 {
            self.memory.last_enemy_origin = origin;
            self.memory.last_enemy_area = area;
        }
    }

    """BotUpdateBattleInventory."""
    def battle_inventory() {
        enemy = self.memory.enemy;
        if enemy is not None {
            battle_inventory(self.memory.inventory, self.bot, self.bot.eye_height, enemy, foe_height(enemy, self.collision));
        }
    }

    """BotChooseWeapon."""
    def choose_weapon() {
        chosen = choose_weapon(self.bot, self.mind, self.memory.inventory);
        if chosen != self.bot.weapon_slot {
            self.bot.weapon_slot = chosen;
            self.bot.weapon_change = 0.0;
        }
    }

    """BotAimAtEnemy: the aim point, and the view toward it."""
    def aim() {
        enemy = self.memory.enemy;
        rule = rule_for(self.rules, self.bot.weapon_slot);
        if enemy is None or rule is None {
            return;
        }
        if self.bot.enemy_sample <= 0.0 {
            # The enemy's motion is remembered every half second.
            self.bot.enemy_sample = 0.5;
            self.bot.enemy_velocity = enemy.velocity.add(Vec3());
            self.bot.enemy_origin = enemy.pos.sub(Vec3(z=foe_height(enemy, self.collision)));
        }
        self.bot.aim_target = aim_point(self.bot, self.mind, rule, enemy, self.collision);
        self.memory.view_mode = "enemy";
    }

    """The travel flags of this think (bs->tfl)."""
    def travel_flags(rocket_jumps: bool) {
        self.memory.travel_flags = bot_travel_flags(self.bot, self.mind, self.bot.liquid_kind, rocket_jumps);
    }

    """The bot's origin (its feet)."""
    def origin() -> Vec3 {
        return self.bot.pos.sub(Vec3(z=self.bot.eye_height));
    }

    def area() -> int {
        mesh = self.mesh;
        return mesh.locate(self.origin()) if mesh is not None else 0;
    }

    """ai_dmnet.c BotReachedGoal."""
    def reached(goal: BotGoal) -> bool {
        swimming = self.bot.water_depth >= 2;
        return reached_goal(
            goal, self.memory.goals, self.origin(), self.bot.pos, self.area(), swimming, self.collision, self.now, self.memory.last_air_time
        );
    }

    """The liquid at a point (AAS_PointContents' water, slime and lava), none
    without a level to sample."""
    def liquid_at(point: Vec3) -> int {
        level = self.level;
        return level.sample_liquid(point).kind if level is not None else 0;
    }

    """BotChooseLTGItem / BotChooseNBGItem through the level items."""
    def choose_item(max_time: float, ltg: BotGoal | None) -> bool {
        items = self.items;
        mesh = self.mesh;
        if items is None or mesh is None {
            return False;
        }
        return choose_item_goal(
            items,
            self.mind.item_weights,
            self.mind.item_numbers,
            self.memory.inventory,
            self.memory.dice,
            self.memory.goals,
            mesh,
            self.origin(),
            self.memory.travel_flags,
            max_time,
            ltg
        );
    }

    """ai_dmnet.c BotGetItemLongTermGoal (a free for all's BotLongTermGoal):
    the goal on top of the stack, or a new one every 20 seconds, when the
    current one is reached or when there is none."""
    def long_term_goal() -> BotGoal | None {
        memory = self.memory;
        goals = memory.goals;
        top = goals.top();
        if top is None {
            memory.ltg_time = 0.0;
        } elif self.reached(top) {
            self.choose_weapon();
            memory.ltg_time = 0.0;
        }
        if memory.ltg_time < self.now {
            goals.pop();
            if self.choose_item(0.0, None) {
                memory.ltg_time = self.now + 20.0;
            } else {
                # "the bot gets sorta stuck with all the avoid timings"
                goals.reset_avoid();
            }
            return goals.top();
        }
        return goals.top();
    }

    """ai_dmnet.c BotNearbyGoal: air when the bot needs it (BotGoForAir), or
    an item worth a detour of `range` hundredths of a second, pushed over the
    long-term goal."""
    def nearby_goal(ltg: BotGoal | None, range: float) -> bool {
        if self.go_for_air(ltg, range) {
            return True;
        }
        return self.choose_item(range, ltg);
    }

    """ai_dmnet.c BotGoForAir: a bot six seconds without air heads for the
    surface above it (BotGetAirGoal), or else for the nearest worthwhile item
    out of the liquid, passing over those in it."""
    def go_for_air(ltg: BotGoal | None, range: float) -> bool {
        memory = self.memory;
        if memory.last_air_time >= self.now - 6.0 {
            return False;
        }
        level = self.level;
        mesh = self.mesh;
        if level is not None and mesh is not None {
            goal = air_goal(self.collision, level.liquids, mesh, self.origin());
            if goal is not None {
                memory.goals.push(goal);
                return True;
            }
        }
        while self.choose_item(range, ltg) {
            top = memory.goals.top();
            if top is not None and self.liquid_at(top.origin) == 0 {
                return True;
            }
            memory.goals.pop();
        }
        memory.goals.reset_avoid();
        return False;
    }

    """Move toward a goal this think (BotMoveToGoal): the combat tick routes
    to it over the AAS."""
    def move_to(goal: BotGoal) {
        self.memory.move_goal = goal;
        self.memory.view_mode = "movement";
    }

    """Whether the bot's movement failed since the last think (no route to
    its goal, or a passage timed out): moveresult.failure, taken once."""
    def movement_failed() -> bool {
        failed = self.memory.move_failed;
        self.memory.move_failed = False;
        return failed;
    }

    """BotAttackMove."""
    def attack_move() {
        enemy = self.memory.enemy;
        if enemy is not None {
            attack_move(self.bot, self.mind, enemy, self.collision);
        }
    }

    # ---- chat (ai_chat.c) -----------------------------------------------

    def chatter() -> BotChatState {
        return self.mind.chat_state;
    }

    """The competitors other than this bot, with their names."""
    def rivals() -> list[tuple[Player, str]] {
        found: list[tuple[Player, str]] = [];
        contest = self.contest;
        if contest is None {
            return found;
        }
        entries = [edge contest->:Competes:->];
        actors = [contest->:Competes:->];
        for i in range(min(len(entries), len(actors))) {
            other = actors[i];
            if other is not self.bot and isinstance(other, Player) {
                found.append((other, entries[i].name));
            }
        }
        return found;
    }

    """ClientName for a player (the scoreboard name), "" for the world."""
    def name_of(actor: Actor | None) -> str {
        contest = self.contest;
        if actor is None or contest is None {
            return "";
        }
        return competitor_name(contest, actor);
    }

    """BotNumActivePlayers > 1."""
    def others_playing() -> bool {
        return len(self.rivals()) > 0;
    }

    """BotRandomOpponentName."""
    def random_opponent_name() -> str {
        rivals = self.rivals();
        if not rivals {
            return "";
        }
        count = int(self.random() * float(len(rivals)));
        for rival in rivals {
            count -= 1;
            if count <= 0 {
                return easy_client_name(rival[1]);
            }
        }
        return easy_client_name(rivals[0][1]);
    }

    """BotVisibleEnemies: any living opponent in sight."""
    def visible_enemies() -> bool {
        for rival in self.rivals() {
            other = rival[0];
            if other.health <= 0 {
                continue;
            }
            if empowered(other, "invisibility") {
                continue;
            }
            if self.sees(other) {
                return True;
            }
        }
        return False;
    }

    """BotValidChatPosition: no powerup running, no lava or slime at the feet
    and no liquid over the head, and standing on the world (not a mover or
    another player)."""
    def valid_chat_position() -> bool {
        bot = self.bot;
        if self.dead() {
            return True;
        }
        for kind in ["quad", "haste", "invisibility", "regen", "flight"] {
            if empowered(bot, kind) {
                return False;
            }
        }
        origin = self.origin();
        if self.liquid_at(origin.sub(Vec3(z=24.0))) in [2, 3] or self.liquid_at(origin.add(Vec3(z=32.0))) > 0 {
            return False;
        }
        floor = self.collision.trace(origin.add(Vec3(z=1.0)), origin.sub(Vec3(z=10.0)));
        return not floor.start_solid and floor.fraction < 1.0 and floor.model <= 0;
    }

    """The ai_chat.c gate every chat shares: not within 25 seconds of the
    last line, as likely as the character's `tendency` (scaled by `scale`),
    and someone to hear it."""
    def may_chat(tendency: float, scale: float = 1.0) -> bool {
        if self.chatter().last_chat > self.now - TIME_BETWEENCHATTING {
            return False;
        }
        if self.random() > tendency * scale {
            return False;
        }
        return self.others_playing();
    }

    """BotAI_BotInitialChat, and the chat time noted (lastchat_time)."""
    def say(kind: str, variables: list[str]) -> bool {
        typed = initial_chat(self.mind.chats, self.mind.random_strings, self.chatter(), kind, variables, self.now, self.memory.dice);
        self.chatter().last_chat = self.now;
        return typed;
    }

    """BotEnterChat: the typed line goes out as `say`, with talk.wav."""
    def enter_chat() {
        line = enter_chat(self.chatter(), self.name_of(self.bot));
        if line {
            self.state.messages.append(line);
            self.state.cues.append("sound/player/talk.wav");
        }
    }

    """BotChat_EnterGame."""
    def chat_enter_game() -> bool {
        if not self.may_chat(self.mind.chat_enter_exit_game) or not self.valid_chat_position() {
            return False;
        }
        mine = easy_client_name(self.name_of(self.bot));
        return self.say("game_enter", [mine, self.random_opponent_name(), "[invalid var]", "[invalid var]", self.map_name]);
    }

    """BotChat_Random (in Seek_LTG)."""
    def chat_random() -> bool {
        if self.chatter().last_chat > self.now - TIME_BETWEENCHATTING {
            return False;
        }
        if self.random() > BOT_THINK_TIME * 0.1 {
            return False;
        }
        if self.random() > self.mind.chat_random or self.random() > 0.25 {
            return False;
        }
        if not self.others_playing() or not self.valid_chat_position() or self.visible_enemies() {
            return False;
        }
        last = self.memory.last_killed_player;
        name = self.random_opponent_name() if last is None else easy_client_name(self.name_of(last));
        kind = "random_misc" if self.random() < self.mind.chat_misc else "random_insult";
        return self.say(kind, [self.random_opponent_name(), name, "[invalid var]", "[invalid var]", self.map_name, random_weapon_name(self.memory.dice)]);
    }

    """BotChat_Kill."""
    def chat_kill() -> bool {
        memory = self.memory;
        victim = memory.last_killed_player;
        if victim is None or victim is self.bot {
            return False;
        }
        if not self.may_chat(self.mind.chat_kill) or not self.valid_chat_position() or self.visible_enemies() {
            return False;
        }
        name = easy_client_name(self.name_of(victim));
        means = memory.enemy_death_means;
        if means == "gauntlet" {
            return self.say("kill_gauntlet", [name]);
        }
        if means == "railgun" {
            return self.say("kill_rail", [name]);
        }
        if means == "telefrag" {
            return self.say("kill_telefrag", [name]);
        }
        if self.random() < self.mind.chat_insult {
            return self.say("kill_insult", [name]);
        }
        return self.say("kill_praise", [name]);
    }

    """BotChat_EnemySuicide."""
    def chat_enemy_suicide() -> bool {
        if not self.may_chat(self.mind.chat_kill) or not self.valid_chat_position() or self.visible_enemies() {
            return False;
        }
        enemy = self.memory.enemy;
        name = easy_client_name(self.name_of(enemy)) if enemy is not None else "";
        return self.say("enemy_suicide", [name]);
    }

    """BotChat_Death, from how the bot died."""
    def chat_death() -> bool {
        memory = self.memory;
        if not self.may_chat(self.mind.chat_death) {
            return False;
        }
        killer = memory.last_killed_by;
        name = easy_client_name(self.name_of(killer)) if killer is not None else "[world]";
        means = memory.bot_death_means;
        weapon = weapon_name_for_means(means);
        if means == "drown" {
            return self.say("death_drown", [self.random_opponent_name()]);
        }
        if means == "environment" {
            return self.say("death_lava", [self.random_opponent_name()]);
        }
        if means == "fall" {
            return self.say("death_cratered", [self.random_opponent_name()]);
        }
        if memory.bot_suicide or means in ["crush", ""] {
            return self.say("death_suicide", [self.random_opponent_name()]);
        }
        if means == "telefrag" {
            return self.say("death_telefrag", [name]);
        }
        if means in ["gauntlet", "railgun", "bfg"] and self.random() < 0.5 {
            kind = "death_gauntlet" if means == "gauntlet" else ("death_rail" if means == "railgun" else "death_bfg");
            return self.say(kind, [name, weapon]);
        }
        if self.random() < self.mind.chat_insult {
            return self.say("death_insult", [name, weapon]);
        }
        return self.say("death_praise", [name, weapon]);
    }

    """BotChat_HitTalking: hurt while typing."""
    def chat_hit_talking() -> bool {
        attacker = self.bot.hurt_by;
        if attacker is None or attacker is self.bot or not isinstance(attacker, Player) {
            return False;
        }
        if not self.may_chat(self.mind.chat_hit_talking, 0.5) or not self.valid_chat_position() {
            return False;
        }
        return self.say("hit_talking", [self.name_of(attacker), weapon_name_for_means(self.bot.hurt_means)]);
    }

    """BotChat_HitNoDeath: hurt and still standing, the attacker out of sight."""
    def chat_hit_no_death() -> bool {
        attacker = self.bot.hurt_by;
        if attacker is None or attacker is self.bot or not isinstance(attacker, Player) {
            return False;
        }
        if not self.may_chat(self.mind.chat_hit_no_death, 0.5) or not self.valid_chat_position() or self.visible_enemies() {
            return False;
        }
        enemy = self.memory.enemy;
        if enemy is not None and isinstance(enemy, Opponent) and enemy.attack_flash > 0.0 {
            return False;
        }
        return self.say("hit_nodeath", [self.name_of(attacker), weapon_name_for_means(self.bot.hurt_means)]);
    }

    """BotChat_HitNoKill: a hit on the enemy, which lives on out of sight."""
    def chat_hit_no_kill() -> bool {
        enemy = self.memory.enemy;
        if enemy is None {
            return False;
        }
        if not self.may_chat(self.mind.chat_hit_no_kill, 0.5) or not self.valid_chat_position() or self.visible_enemies() {
            return False;
        }
        if isinstance(enemy, Opponent) and enemy.attack_flash > 0.0 {
            return False;
        }
        return self.say("hit_nokill", [self.name_of(enemy), weapon_name_for_means(enemy.hurt_means)]);
    }

    # ---- the nodes (ai_dmnet.c AINode_*) --------------------------------

    """AINode_Seek_LTG."""
    can seek_long_term_goal with SeekLongTermGoal entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        if self.chat_random() {
            memory.stand_time = self.now + chat_time();
            visit self.enter(here, "stand");
            return;
        }
        self.travel_flags(True);
        memory.enemy = None;
        # A taunt now and then just after a kill (EA_Gesture).
        if memory.killed_enemy_time > self.now - 2.0 and self.random() < BOT_THINK_TIME {
            memory.gesture = True;
        }
        if self.find_enemy(None) {
            if wants_to_retreat(memory.inventory, self.bot.weapon_slot) {
                visit self.enter(here, "battle_retreat");
            } else {
                memory.goals.empty();
                visit self.enter(here, "battle_fight");
            }
            return;
        }
        goal = self.long_term_goal();
        if goal is None {
            return;
        }
        # "if the movement failed": a new long-term goal next think.
        if self.movement_failed() {
            memory.ltg_time = 0.0;
        }
        if memory.check_time < self.now {
            memory.check_time = self.now + 0.5;
            if self.nearby_goal(goal, 150.0) {
                memory.nbg_time = self.now + 4.0 + 150.0 * 0.01;
                visit self.enter(here, "seek_nbg");
                return;
            }
        }
        self.move_to(goal);
    }

    """AINode_Seek_NBG."""
    can seek_nearby_goal with SeekNearbyGoal entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        self.travel_flags(True);
        memory.enemy = None;
        goal = memory.goals.top();
        if goal is None {
            memory.nbg_time = 0.0;
        } elif self.reached(goal) {
            self.choose_weapon();
            memory.nbg_time = 0.0;
        }
        if memory.nbg_time < self.now {
            memory.goals.pop();
            # "check for new nearby items right away"
            memory.check_time = self.now + 0.05;
            visit self.enter(here, "seek_ltg");
            return;
        }
        if goal is not None {
            self.move_to(goal);
        }
        if self.movement_failed() {
            memory.nbg_time = 0.0;
        }
        if self.find_enemy(None) {
            if wants_to_retreat(memory.inventory, self.bot.weapon_slot) {
                visit self.enter(here, "battle_nbg", False);
            } else {
                memory.goals.empty();
                visit self.enter(here, "battle_fight", False);
            }
        }
    }

    """AINode_Battle_Fight."""
    can battle_fight with BattleFight entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        # "if there is another better enemy"
        self.find_enemy(memory.enemy);
        enemy = memory.enemy;
        if enemy is None {
            visit self.enter(here, "seek_ltg");
            return;
        }
        if memory.enemy_death_time > 0.0 {
            if memory.enemy_death_time < self.now - 1.0 {
                memory.enemy_death_time = 0.0;
                if memory.enemy_suicide {
                    self.chat_enemy_suicide();
                }
                if memory.last_killed_player is enemy and self.chat_kill() {
                    memory.stand_time = self.now + chat_time();
                    visit self.enter(here, "stand");
                } else {
                    memory.ltg_time = 0.0;
                    visit self.enter(here, "seek_ltg");
                }
                return;
            }
        } elif enemy.health <= 0 {
            memory.enemy_death_time = self.now;
        }
        # An invisible enemy that is not shooting is easily lost.
        if empowered(enemy, "invisibility")
            and not (isinstance(enemy, Opponent) and enemy.attack_flash > 0.0)
            and self.random() < 0.2 {
            visit self.enter(here, "seek_ltg");
            return;
        }
        self.note_enemy_spot();
        self.battle_inventory();
        if memory.last_frame_health > memory.inventory[INVENTORY_HEALTH] and self.chat_hit_no_death() {
            memory.stand_time = self.now + chat_time();
            visit self.enter(here, "stand");
            return;
        }
        if self.bot.hits_landed > memory.last_hit_count and self.chat_hit_no_kill() {
            memory.stand_time = self.now + chat_time();
            visit self.enter(here, "stand");
            return;
        }
        if memory.enemy_death_time <= 0.0 and not self.enemy_visible() {
            if wants_to_chase(memory.inventory, self.bot.weapon_slot) {
                visit self.enter(here, "battle_chase");
            } else {
                visit self.enter(here, "seek_ltg");
            }
            return;
        }
        self.travel_flags(True);
        self.choose_weapon();
        self.attack_move();
        self.aim();
        self.bot.fighting = True;
        if not memory.suicidal and wants_to_retreat(memory.inventory, self.bot.weapon_slot) {
            self.enter(here, "battle_retreat", False);
        }
    }

    """AINode_Battle_Chase."""
    can battle_chase with BattleChase entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        enemy = memory.enemy;
        if enemy is None {
            visit self.enter(here, "seek_ltg");
            return;
        }
        if self.enemy_visible() {
            visit self.enter(here, "battle_fight");
            return;
        }
        if self.find_enemy(None) {
            visit self.enter(here, "battle_fight");
            return;
        }
        if memory.last_enemy_area == 0 {
            visit self.enter(here, "seek_ltg");
            return;
        }
        self.travel_flags(True);
        goal = BotGoal(origin=memory.last_enemy_origin, area=memory.last_enemy_area);
        if touching_goal(self.origin(), goal) {
            memory.chase_time = 0.0;
        }
        if memory.chase_time <= 0.0 or memory.chase_time < self.now - 10.0 {
            visit self.enter(here, "seek_ltg");
            return;
        }
        if memory.check_time < self.now {
            memory.check_time = self.now + 1.0;
            if self.nearby_goal(goal, 150.0) {
                memory.nbg_time = self.now + 0.1 * 150.0 + 1.0;
                visit self.enter(here, "battle_nbg");
                return;
            }
        }
        self.battle_inventory();
        self.move_to(goal);
        if memory.chase_time > self.now - 2.0 {
            memory.view_mode = "chase";
        }
        if self.area() == memory.last_enemy_area {
            memory.chase_time = 0.0;
        }
        if wants_to_retreat(memory.inventory, self.bot.weapon_slot) {
            self.enter(here, "battle_retreat", False);
        }
    }

    """AINode_Battle_Retreat."""
    can battle_retreat with BattleRetreat entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        enemy = memory.enemy;
        if enemy is None or enemy.health <= 0 {
            visit self.enter(here, "seek_ltg");
            return;
        }
        self.find_enemy(enemy);
        self.travel_flags(False);
        self.battle_inventory();
        if wants_to_chase(memory.inventory, self.bot.weapon_slot) {
            memory.goals.empty();
            visit self.enter(here, "battle_chase");
            return;
        }
        if self.enemy_visible() {
            memory.enemy_visible_time = self.now;
            self.note_enemy_spot();
        }
        if memory.enemy_visible_time < self.now - 4.0 {
            visit self.enter(here, "seek_ltg");
            return;
        } elif memory.enemy_visible_time < self.now and self.find_enemy(None) {
            visit self.enter(here, "battle_fight");
            return;
        }
        goal = self.long_term_goal();
        if goal is None {
            # "battle retreat: no way out" (AIEnter_Battle_SuicidalFight)
            visit self.enter(here, "battle_fight");
            memory.suicidal = True;
            return;
        }
        if memory.check_time < self.now {
            memory.check_time = self.now + 1.0;
            if self.nearby_goal(goal, 150.0) {
                memory.nbg_time = self.now + 150.0 / 100.0 + 1.0;
                visit self.enter(here, "battle_nbg");
                return;
            }
        }
        self.move_to(goal);
        if self.movement_failed() {
            memory.ltg_time = 0.0;
        }
        self.choose_weapon();
        if self.mind.attack_skill > 0.3 {
            self.aim();
        }
    }

    """AINode_Battle_NBG."""
    can battle_nearby_goal with BattleNearbyGoal entry {
        memory = self.memory;
        if self.dead() {
            visit self.enter(here, "respawn");
            return;
        }
        enemy = memory.enemy;
        if enemy is None or enemy.health <= 0 {
            visit self.enter(here, "seek_nbg");
            return;
        }
        self.travel_flags(True);
        if self.enemy_visible() {
            memory.enemy_visible_time = self.now;
            self.note_enemy_spot();
        }
        goal = memory.goals.top();
        if goal is None or self.reached(goal) {
            memory.nbg_time = 0.0;
        }
        if memory.nbg_time < self.now {
            memory.goals.pop();
            if memory.goals.top() is not None {
                visit self.enter(here, "battle_retreat");
            } else {
                visit self.enter(here, "battle_fight");
            }
            return;
        }
        if goal is not None {
            self.move_to(goal);
        }
        if self.movement_failed() {
            memory.nbg_time = 0.0;
        }
        self.battle_inventory();
        self.choose_weapon();
        if self.mind.attack_skill > 0.3 {
            self.aim();
        }
    }

    """AINode_Stand: typing a chat line, then saying it."""
    can stand with Stand entry {
        memory = self.memory;
        if memory.last_frame_health > self.bot.health and self.chat_hit_talking() {
            memory.stand_find_enemy_time = self.now + chat_time() + 0.1;
            memory.stand_time = self.now + chat_time() + 0.1;
        }
        if memory.stand_find_enemy_time < self.now {
            if self.find_enemy(None) {
                visit self.enter(here, "battle_fight");
                return;
            }
            memory.stand_find_enemy_time = self.now + 1.0;
        }
        memory.talking = True;
        if memory.stand_time < self.now {
            self.enter_chat();
            memory.talking = False;
            visit self.enter(here, "seek_ltg");
        }
    }

    """AINode_Respawn: dead, perhaps saying something, then back in."""
    can respawn with Respawn entry {
        memory = self.memory;
        if memory.respawn_waiting {
            if not self.dead() {
                visit self.enter(here, "seek_ltg");
            }
        } elif memory.respawn_time < self.now {
            memory.respawn_waiting = True;
            # EA_Respawn: back in once the game allows it.
            self.bot.respawn_wait = max(0.0, memory.respawn_minimum - self.now);
            if memory.respawn_chat_time > 0.0 {
                self.enter_chat();
                memory.enemy = None;
            }
        }
        memory.talking = memory.respawn_chat_time > 0.0 and memory.respawn_chat_time < self.now - 0.5 and not memory.respawn_waiting;
    }
}

"""ai_dmq3.c BotCheckSnapshot's EV_OBITUARY: what the bot killed, what
killed it, and whether its enemy killed itself."""
def read_obituaries(bot: Opponent, memory: BotState, contest: ArenaMatch, now: float) {
    for death in contest.obituaries {
        if death.serial <= memory.obituary_serial {
            continue;
        }
        memory.obituary_serial = death.serial;
        killer = death.killer;
        if death.victim is bot {
            memory.bot_death_means = death.means;
            memory.last_killed_by = killer if isinstance(killer, Player) else None;
            memory.bot_suicide = killer is None or killer is bot;
        } elif killer is bot {
            memory.enemy_death_means = death.means;
            memory.last_killed_player = death.victim if isinstance(death.victim, Player) else None;
            memory.killed_enemy_time = now;
        } elif killer is memory.enemy and death.victim is killer {
            memory.enemy_suicide = True;
        }
    }
}

"""Every Q3 bot, every frame (ai_main.c BotAIStartFrame): BotDeathmatchAI
when its think is due, then what it does between thinks (act_bot: its view
and trigger). It also keeps the level items current (BotUpdateEntityItems) on
the level clock the AI runs by. `level` answers what liquid is where (air
goals, chat positions); `intermission` is BotIntermission, the podium after
the match, when bots think but neither move nor act."""
walker BotTactics {
    has player: Player,
        collision: CollisionMap,
        state: CombatState,
        rules: list[WeaponRule],
        dt: float,
        map_name: str = "",
        level: Level | None = None,
        intermission: bool = False,
        world: World | None = None,
        brain: BotBrain | None = None,
        mesh: NavMesh | None = None,
        items: BotItems | None = None,
        contest: ArenaMatch | None = None;

    can begin with World entry {
        self.world = here;
        self.brain = bot_brain(here);
        meshes = [here->:HasNavMesh:->][?:NavMesh];
        self.mesh = meshes[0] if meshes else None;
        self.items = bot_items(here);
        self.contest = match_of(here);
        items = self.items;
        mesh = self.mesh;
        if items is not None and mesh is not None and self.dt > 0.0 {
            items spawn UpdateLevelItems(mesh=mesh, collision=self.collision, dt=self.dt, world=here);
        }
        if self.dt > 0.0 and self.rules {
            visit [here->:HasOpponent:->];
        }
    }

    can think with Opponent entry {
        mind = here.character;
        brain = self.brain;
        if not here.arena or here.dormant or mind is None or brain is None {
            return;
        }
        memory = here.bot_state;
        if memory.clock == 0.0 {
            # Bots join at different moments, so their thinks fall on
            # different frames (each keeps its own bot_thinktime phase).
            here.think_wait = float(here.shot_random % 12) / 120.0;
        }
        memory.clock += self.dt;
        here.think_wait -= self.dt;
        memory.thought = here.think_wait <= 0.0;
        if not memory.thought {
            return;
        }
        here.think_wait += BOT_THINK_TIME;
        items = self.items;
        now = items.clock if items is not None else memory.clock;
        contest = self.contest;
        if memory.last_frame_health < 0 {
            # A fresh state (a new bot or a respawn): what came before is
            # history.
            memory.last_frame_health = here.health;
            memory.last_hit_count = here.hits_landed;
            memory.dice.state = max(1, here.shot_random);
            if contest is not None {
                memory.obituary_serial = contest.obituary_serial;
            }
        }
        chatter = mind.chat_state;
        if chatter.entered < 0.0 {
            chatter.entered = now;
        }
        if not self.intermission {
            # BotUpdateInventory, BotCheckSnapshot and BotCheckAir.
            memory.inventory = bot_inventory(here);
            if contest is not None {
                read_obituaries(here, memory, contest, now);
            }
            if here.water_depth < 3 or empowered(here, "battlesuit") {
                memory.last_air_time = now;
            }
        }
        memory.move_goal = None;
        memory.view_mode = "movement";
        memory.talking = False;
        here.fighting = False;
        thinker = BotThink(
            bot=here,
            mind=mind,
            memory=memory,
            collision=self.collision,
            rules=self.rules,
            now=now,
            human=self.player,
            state=self.state,
            mesh=self.mesh,
            items=items,
            contest=contest,
            map_name=self.map_name,
            level=self.level,
            intermission=self.intermission
        );
        # "if the bot entered the game less than 8 seconds ago"
        if not chatter.entered_chat and chatter.entered > now - 8.0 and here.health > 0 {
            chatter.entered_chat = True;
            if thinker.chat_enter_game() {
                memory.stand_time = now + chat_time();
                memory.ainode = "stand";
                memory.battle = "";
                memory.stand_find_enemy_time = now + 1.0;
            }
        }
        brain spawn thinker;
        memory.last_frame_health = here.health;
        memory.last_hit_count = here.hits_landed;
        self.apply(here, memory);
    }

    can act with Opponent entry {
        mind = here.character;
        world = self.world;
        if not here.arena or here.health <= 0 or here.dormant or mind is None or world is None {
            return;
        }
        act_bot(world, here, mind, self.player, self.collision, self.state, self.rules, self.dt);
    }

    """Hand the think's decisions to the body: the goal the combat tick
    routes to (at the bot's eye height over the goal, in the goal's AAS
    area), the movement weapon, and whether it is on the move at all."""
    def apply(bot: Opponent, memory: BotState) {
        goal = memory.move_goal;
        if goal is not None and not bot.fighting {
            bot.arena_goal = goal.origin.add(Vec3(z=bot.eye_height));
            memory.goal_area = goal.area;
            bot.alert = max(bot.alert, 1.0);
        } else {
            bot.arena_goal = None;
            memory.goal_area = 0;
        }
        if not bot.fighting {
            bot.crouched = False;
        }
        # MOVERESULT_MOVEMENTWEAPON: the movement's weapon (a rocket jump's).
        wanted = memory.travel.weapon;
        if wanted and not bot.fighting {
            for rule in self.rules {
                if rule.key == wanted and rule.slot != bot.weapon_slot and armed_with(bot, rule) {
                    bot.weapon_slot = rule.slot;
                    bot.weapon_change = 0.0;
                }
            }
        }
    }
}

