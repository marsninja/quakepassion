# Content packs

What QuakePassion plays beyond the three games: their mission packs and the
2021 Quake re-release's episodes. The packs are found, listed and loaded; the
monsters, weapons, items and map mechanics they add are not implemented yet,
and the last section lists them pack by pack.

## What a pack is

A pack is a body of maps and assets published on top of a game, in its own
folder. It plays by that game's formats and rules (`q1`, `q2` or `q3`), and
its files are searched over the files beneath it, as the original engines'
`-game` searched a mission pack's folder before the base game's.

`engine/assets/content.jac` models this as a graph: a `ContentPack` node for
each pack, an `Over` edge to the pack beneath it, and a `Layers` walker that
climbs those edges to give the folders to search, base first. Everything that
opens archives (the asset library, the pk3 reader, the level loader, the
config reader) takes that search path: the folders joined by `;`, later ones
over earlier ones.

| Pack id | Title | Game | Folder under the assets root | Over |
| --- | --- | --- | --- | --- |
| `q1` | Quake | q1 | `id1` | |
| `hipnotic` | Scourge of Armagon | q1 | `quake/hipnotic` | `q1` |
| `rogue` | Dissolution of Eternity | q1 | `quake/rogue` | `q1` |
| `q1r` | Quake (2021 re-release) | q1 | `quake/rerelease/id1` | `q1` |
| `dopa` | Dimension of the Past | q1 | `quake/rerelease/dopa` | `q1r` |
| `mg1` | Dimension of the Machine | q1 | `quake/rerelease/mg1` | `q1r` |
| `mg3` | The Thirtieth Passing (mg3) | q1 | `quake/rerelease/mg3` | `q1r` |
| `q1ctf` | Threewave CTF | q1 | `quake/rerelease/ctf` | `q1r` |
| `q2` | Quake II | q2 | `baseq2` | |
| `xatrix` | The Reckoning | q2 | `quake2/xatrix` | `q2` |
| `groundzero` | Ground Zero | q2 | `quake2/rogue` | `q2` |
| `q2ctf` | Capture the Flag | q2 | `quake2/ctf` | `q2` |
| `q3` | Quake III Arena | q3 | `baseq3` | |
| `teamarena` | Team Arena | q3 | `quake3/missionpack` | `q3` |

The folders are the Steam installs' own, under one assets root
(`~/quake-assets`, or the parent of `QP_ASSETS`). A pack whose folder is
missing is not listed. `mg3`'s title is its start map's; the episode's own
name is not in its files.

Not supported: the 2023 Quake II re-release (`quake2/rerelease`, which needs
the extended map format, MD5 models and OGV video, and mostly repeats maps
the original packs have) and Quake II RTX's media.

## Choosing a pack

- **Menu**: each game's tab lists its installed packs beside its maps. Click
  a pack, or press Left and Right, to list its own maps (not the ones beneath
  it); a pack's `start` map is listed first, and Quake and Quake II maps show
  the title their worldspawn gives them.
- **`QP_PACK=<id>`** starts in a pack, on its `start` map or its campaign's
  first map; `QP_MAP` still names another.
- **Saves** record the pack they were made in (`PACK <id>`), since packs
  share map names: seven of Quake's eight have a `start`.

A game plays one pack at a time. Loading a map from the menu plays the pack
it was listed under; the console's `map` loads from the pack being played.

## Formats

- **BSP2** (`engine/formats/q1/bsp.jac`): the re-release's episodes are BSP2,
  which is BSP29 with the 16-bit counts and indices of faces, edges, leaves,
  nodes and clip nodes widened to 32 bits and leaf and node bounds held as
  floats. One reader reads both.
- **Lightmap extents** are taken from texture coordinates rounded to single
  precision, as `CalcSurfaceExtents` and the light compilers do. In double
  precision one face of `mgdm3` and of `test_button` came out a texel wider
  than the lighting lump holds.
- **Entity numbers** are read with C's `atof` and `atoi`
  (`engine/formats/numbers.jac`), as `ED_ParseField` reads them: the number
  the text starts with, 0 when it starts with none. Shipped maps rely on it:
  The Reckoning's `xswamp` has `"delay" ""`, Ground Zero's `rhangar1` has
  `"delay" "speed"`.
- **Entity text** is decoded as bytes (Latin-1), not UTF-8: Quake's high
  characters are its bronze letters.
- **Quake III vertices** may carry lightmap coordinates that are not numbers
  where q3map gave a surface no lightmap (Team Arena's `mpterra3`); they are
  read as 0.

Not read yet: the re-release's coloured lighting (`.lit`), MD5 models, PNG
and TGA replacement textures, OGG soundtracks in the packs' `music` folders,
and BSPX lumps (`mg3` carries face normals).

## Validation

`scripts/map_sweep.jac` loads every map of every installed pack through the
game, runs two seconds of simulation and renders a frame
(`QP_SWEEP_PACKS=hipnotic,xatrix,...` limits it to some packs). On the eleven
packs above other than the base games, 253 of 254 maps pass:

| Pack | Maps |
| --- | --- |
| Scourge of Armagon | 18 |
| Dissolution of Eternity | 17 |
| Quake (2021 re-release) | 68 |
| Dimension of the Past | 13 |
| Dimension of the Machine | 25 |
| The Thirtieth Passing (mg3) | 20 |
| Threewave CTF | 10 |
| The Reckoning | 25 |
| Ground Zero | 32 |
| Capture the Flag | 5 |
| Team Arena | 20 of 21 |

Team Arena's `texturegrab` does not load ("Invalid BSP table index"); it is
a texture reference sheet, not a level.

Passing the sweep means a map loads, simulates and draws. It does not mean
the map plays as its pack intends: see the next section.

## What the packs add, and is not implemented

A map entity whose class the engine does not know is skipped without a
message, so a pack's maps load with its additions absent: no new monsters,
weapons or items, and none of the new brush entities and triggers, which in
places means a door that never opens or a bridge that is not there. The
classes below are each pack's, counted against its base game's maps.

Also outside the engine today, whatever the pack: team game modes (capture
the flag in all three games; Team Arena's one-flag CTF, Harvester and
Overload), and the Quake III entity filter drops everything that is not for
free-for-all.

### Scourge of Armagon (`hipnotic`)

60 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_armagon`, `monster_gremlin`, `monster_scourge` |
| Weapons | `weapon_laser_gun`, `weapon_mjolnir`, `weapon_proximity_gun` |
| Items | `item_artifact_empathy_shields`, `item_artifact_wetsuit`, `item_hornofconjuring` |
| Brush entities | `func_bobbingwater`, `func_breakawaywall`, `func_clock`, `func_counter`, `func_earthquake`, `func_exploder`, `func_movewall`, `func_multi_exploder`, `func_oncount`, `func_particlefield`, `func_rotate_door`, `func_rotate_entity`, `func_rotate_train`, `func_rubble`, `func_rubble1`, `func_rubble2`, `func_rubble3`, `func_spawn`, `func_spawn_small`, `func_togglewall`, `func_train2` |
| Triggers | `trigger_damagethreshold`, `trigger_decoy_use`, `trigger_setgravity`, `trigger_usekey`, `trigger_waterfall` |
| Traps | `trap_gods_wrath`, `trap_gravity_well`, `trap_lightning_switched`, `trap_lightning_triggered`, `trap_shooter`, `trap_spike_mine`, `trap_tesla_coil` |
| Paths | `path_follow`, `path_follow2`, `path_rotate` |
| Markers | `info_notnull`, `info_rotate`, `info_startendtext` |
| Effects | `effect_finale`, `effect_teleport` |
| Ambient sounds | `ambient_fan_blowing`, `ambient_flouro_buzz`, `ambient_humming`, `ambient_light_buzz`, `ambient_riftpower`, `ambient_running_water`, `ambient_rushing` |
| Other | `play_sound_triggered`, `random_thunder_triggered`, `rotate_object` |

### Dissolution of Eternity (`rogue`)

39 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_dragon`, `monster_eel`, `monster_lava_man`, `monster_morph`, `monster_mummy`, `monster_super_wrath`, `monster_sword`, `monster_wrath` |
| Items | `item_flag`, `item_flag_team1`, `item_flag_team2`, `item_lava_spikes`, `item_multi_rockets`, `item_plasma`, `item_powerup_belt`, `item_powerup_shield`, `item_random_powerup`, `item_sphere`, `item_time_core`, `item_time_machine` |
| Team objectives | `info_player_team1`, `info_player_team2` |
| Brush entities | `func_ctf_wall`, `func_elvtr_button`, `func_new_plat` |
| Triggers | `trigger_earthquake`, `trigger_earthquake_kill` |
| Markers | `info_notnull`, `info_overlord_destination` |
| Lights | `light_candle`, `light_lantern` |
| Other | `buzzsaw`, `dmatch_tag_token`, `dragon_corner`, `earthquake`, `ltrail_end`, `ltrail_relay`, `ltrail_start`, `pendulum` |

### Quake (2021 re-release) (`q1r`)

8 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_dragon` |
| Brush entities | `func_dm_only` |
| Markers | `info_notnull` |
| Lights | `light_torch_3legs_white`, `light_torch_tall_3legs_yellow` |
| Other | `plat_4x128`, `sound_thunder`, `sound_wind1` |

### Dimension of the Past (`dopa`)

4 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Brush entities | `func_explode` |
| Markers | `info_fog` |
| Ambient sounds | `ambient_flouro_buzz`, `ambient_light_buzz` |

### Dimension of the Machine (`mg1`)

47 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_ogre_marksman` |
| Brush entities | `func_bob`, `func_explode`, `func_hurt`, `func_toss` |
| Triggers | `trigger_activate_coop_spawns`, `trigger_changetarget`, `trigger_cleanup_corpses`, `trigger_counter_timed`, `trigger_explosion`, `trigger_fade`, `trigger_fog`, `trigger_fog_transition`, `trigger_lightning`, `trigger_repeater`, `trigger_screenshake`, `trigger_sound` |
| Targets | `target_lightramp` |
| Markers | `info_fog`, `info_horde_ammo`, `info_horde_item`, `info_horde_key`, `info_monster_start`, `info_monster_start_boss`, `info_monster_start_flying`, `info_notnull`, `info_player_start_hub`, `info_rotate_axis` |
| Scenery | `misc_corpse`, `misc_rune_indicator` |
| Effects | `particle_embers`, `particle_embers_tall`, `particle_tele`, `particle_tele_fountain` |
| Lights | `light_candle`, `light_flame_gas` |
| Ambient sounds | `ambient_flouro_buzz`, `ambient_generic`, `ambient_light_buzz` |
| Other | `dynamiclight`, `horde_manager`, `hub_trigger_changelevel`, `mge2m2_electrode_button`, `mge2m2_electrode_target`, `mge2m2_rune_egg_opener`, `mge2m2_rune_pickup_fixer`, `rotate_object_continuously` |

### The Thirtieth Passing (mg3) (`mg3`)

76 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_army_infected`, `monster_boss_final`, `monster_demodog`, `monster_enforcer_infected`, `monster_ghost`, `monster_hell_knight_infected`, `monster_knight_infected`, `monster_lava_man`, `monster_ogre_marksman`, `monster_ogre_rocket`, `monster_oldone_new`, `monster_orb`, `monster_ranged_knight`, `monster_slime`, `monster_super_shambler` |
| Weapons | `weapon_bloody_sg`, `weapon_bloody_ssg`, `weapon_laser_gun`, `weapon_mjolnir` |
| Items | `item_armor_shard`, `item_artifact_lavasuit`, `item_draught_insight`, `item_draught_stupor`, `item_head_hellknight`, `item_upgrade_cells`, `item_upgrade_health`, `item_upgrade_nails`, `item_upgrade_rockets`, `item_upgrade_shells` |
| Brush entities | `func_axe_button`, `func_bob`, `func_breakable`, `func_explode`, `func_hurt`, `func_toss` |
| Triggers | `trigger_activate_coop_spawns`, `trigger_always`, `trigger_bloodynightmare_relay`, `trigger_boss_teleport`, `trigger_counter_timed`, `trigger_door_relay`, `trigger_explosion`, `trigger_explosion_repeater`, `trigger_fog_transition`, `trigger_heal`, `trigger_health_relay`, `trigger_lightning`, `trigger_lore`, `trigger_multitouch`, `trigger_music`, `trigger_relay_setskill`, `trigger_repeater`, `trigger_rune_counter`, `trigger_rune_relay`, `trigger_sacrifice_counter`, `trigger_screenshake`, `trigger_sound`, `trigger_teleport_silent` |
| Markers | `info_boss_teleport_boss`, `info_boss_teleport_first`, `info_boss_teleport_second`, `info_fog`, `info_notnull`, `info_szombie_spawn` |
| Scenery | `misc_corpse`, `misc_model`, `misc_rope`, `misc_sacrifice` |
| Effects | `particle_embers`, `particle_embers_tall`, `particle_tele` |
| Lights | `light_candle` |
| Ambient sounds | `ambient_flouro_buzz`, `ambient_generic`, `ambient_light_buzz` |
| Other | `rotate_object_continuously` |

### Threewave CTF (`q1ctf`)

7 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Items | `item_flag_team1`, `item_flag_team2` |
| Team objectives | `info_player_team1`, `info_player_team2` |
| Markers | `info_notnull` |
| Ambient sounds | `ambient_flouro_buzz`, `ambient_light_buzz` |

### The Reckoning (`xatrix`)

21 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_boss5`, `monster_chick_heat`, `monster_fixbot`, `monster_gekk`, `monster_gladb`, `monster_soldier_hypergun`, `monster_soldier_lasergun`, `monster_soldier_ripper` |
| Weapons | `weapon_boomer`, `weapon_phalanx` |
| Ammunition | `ammo_magslug`, `ammo_trap` |
| Items | `item_quadfire`, `key_green_key` |
| Brush entities | `func_object_repair` |
| Targets | `target_mal_laser` |
| Scenery | `misc_amb4`, `misc_nuke`, `misc_transport`, `misc_viper_missile` |
| Other | `rotating_light` |

### Ground Zero (`groundzero`)

40 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Monsters | `monster_carrier`, `monster_daedalus`, `monster_medic_commander`, `monster_stalker`, `monster_turret`, `monster_widow`, `monster_widow2` |
| Weapons | `weapon_chainfist`, `weapon_disintegrator`, `weapon_etf_rifle`, `weapon_heatbeam`, `weapon_nailgun`, `weapon_plasmabeam`, `weapon_proxlauncher` |
| Ammunition | `ammo_disruptor`, `ammo_flechettes`, `ammo_nails`, `ammo_nuke`, `ammo_prox`, `ammo_tesla` |
| Items | `item_doppleganger`, `item_double`, `item_ir_goggles`, `item_sphere_defender`, `item_sphere_hunter`, `item_sphere_vengeance`, `key_nuke`, `key_nuke_container` |
| Brush entities | `func_plat2` |
| Triggers | `trigger_disguise` |
| Targets | `target_anger`, `target_blacklight`, `target_killplayers`, `target_orb`, `target_steam` |
| Markers | `info_player_coop_lava` |
| Scenery | `misc_nuke_core` |
| Other | `dm_tag_token`, `hint_path`, `turret_invisible_brain` |

### Capture the Flag (`q2ctf`)

6 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Items | `item_flag_team1`, `item_flag_team2` |
| Team objectives | `info_player_team1`, `info_player_team2` |
| Scenery | `misc_ctf_banner`, `misc_ctf_small_banner` |

### Team Arena (`teamarena`)

18 entity classes the base game does not have.

| Kind | Classes |
| --- | --- |
| Weapons | `weapon_chaingun`, `weapon_nailgun`, `weapon_prox_launcher` |
| Ammunition | `ammo_belt`, `ammo_mines`, `ammo_nails` |
| Items | `holdable_invulnerability`, `holdable_kamikaze`, `item_ammoregen`, `item_botroam`, `item_doubler`, `item_guard`, `item_scout` |
| Team objectives | `team_CTF_neutralflag`, `team_blueobelisk`, `team_neutralobelisk`, `team_redobelisk` |
| Other | `shooter_rocket` |
