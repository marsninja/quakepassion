# Menu, console and configuration

QuakePassion has one Escape menu for all games (levels, settings, controls), a
drop-down console with each game's commands, cvars, aliases and key bindings,
and a per-user configuration written as console scripts. Every setting is a
cvar; every key does what its binding says. Each game starts from its own
`default.cfg`.

## Escape menu

`engine/core/menu.jac` `LevelMenu`; actions run in
`engine/core/impl/app.impl.jac` and `app.commands.impl.jac`.

- **Escape** opens and closes the menu (`togglemenu`); if the console is down,
  Escape puts it away first. While the menu is open the game is paused, the
  cursor is released, and it is restored on resume. The 1280×720 panel stays
  centred in any window size.
- **Levels.** Tabs for Quake, Quake II, Quake III and Passion. Maps are listed
  from the installed archives (`~/quake-assets/id1`, `baseq2`, `baseq3`;
  `QP_ASSETS` replaces the directory of the game `QP_GAME` names). Q1
  brush-model BSPs are left out (`is_q1_level`). Quake III lists its
  single-player ladder first, with each arena's name and best finish. Passion
  offers twelve fresh expedition seeds. Up/Down, the wheel or a click select;
  Enter or **Render selected level** loads. A load that fails keeps the current
  level and shows the error. Loading is synchronous.
- **Settings** (Up/Down, Left/Right or Enter, or click the arrows): movement
  (walk or fly), field of view (`fov`), mouse sensitivity (`sensitivity`),
  invert mouse (`m_pitch` sign), always run (`cl_run`), fly speed
  (`qp_flyspeed`), frame limit (`host_maxfps`: uncapped, 30, 60, 120, 144,
  240), fullscreen (`vid_fullscreen`), window size (`vid_width` ×
  `vid_height`, seven modes), visibility culling (`r_novis`), diagnostic
  overlay (`qp_overlay`), crosshair (`crosshair`), sound and music volume
  (`volume`, `bgmvolume`), god mode (`qp_god`) and skill (`skill`, from the
  next level; the fifth is Q3's Nightmare!, played as Nightmare in Q1/Q2).
  Each change is saved at once. **Reset defaults** returns every archived cvar
  to its default (`Cvar_Restart_f`) and walking.
- **Controls** (Q1/Q2 Customize Controls, Q3 `ui_controls2.c`): the game's
  actions from `games/controls.jac` `GAME_CONTROL_ACTIONS`, then the engine's
  (console, walk/fly, overlay, quick save, quick load, screenshot), each with
  its keys. Enter or a click waits for a key; an action holds two keys and a
  third replaces them (`M_Keys_Key`). Backspace or Delete clears the row.
  **Reset defaults** deletes the game's bindings file and runs its defaults
  again. Changes are saved to the bindings file.
- **Quit** exits; so does the window's close button or `quit`.

## Console

`engine/console/console.jac` (drawing and line editing), `shell.jac` (the
command graph and buffer), `cvar.jac` (cvars).

- **Opening.** The backquote key (hard-wired, so it cannot be unbound, as in
  Q3), shift+Escape (ioquake3) or `toggleconsole`. It slides over the top half
  of the view at `scr_conspeed`, drawn in each game's style: Quake's
  `gfx/conback.lmp` and Quake II's `pics/conback.pcx` with `conchars`, Quake
  III's scrolling `console` shader with `bigchars` and `^0`-`^7` colours; a
  plain panel without the art. Printed lines also show at the top of the view
  for `con_notifytime` seconds. Q2 and Q3 pause single-player play while it is
  down; Q1 keeps running, as the originals do.
- **Editing.** Enter runs the line; Tab completes command, cvar and alias names
  (listing them when several match); Up/Down walk the last 32 lines;
  PgUp/PgDn and the wheel scroll back; ctrl+Home/End jump; ctrl+V or
  shift+Insert paste.
- **The shell graph.** A `Shell` node `Declares` every `ConsoleName`: `Cvar`,
  `Command` and `Alias` nodes. `FindName`, `Roster` and `Execute` walkers find
  a name, list names and run a command line (`Cmd_ExecuteString`). A command
  names its owner: the shell runs its own and hands the rest back to the keys,
  input or host (`App.execute_commands`).
- **The command buffer** (`Cbuf_AddText`/`Cbuf_InsertText`) splits on `;` and
  newlines outside quotes, skips `//` and `/* */` comments, and stops at `wait`
  until the next frame. A runaway alias stops after 16 expansions
  (`ALIAS_LOOP_COUNT`).
- **Cvars** (`Cvar_Get`, `Cvar_Set`) keep their text and number, are typed
  (string, bool, int, float) and clamped to their range, and may answer to
  other games' names for the same setting (`s_volume` for `volume`, `cg_fov`
  for `fov`). `set` on an unknown name creates a user cvar that a subsystem
  registering it later adopts. Typing a cvar's name shows it; a value after it
  sets it. `ARCHIVE` cvars are saved; `ROM` cvars cannot be set.

### Commands

| Owner | Commands |
|---|---|
| Shell | `set`, `seta`, `toggle`, `reset`, `cvar_restart`, `cvarlist`, `cmdlist`, `alias`, `echo`, `wait`, `vstr`, `clear` |
| Keys (`engine/input/keys.jac`) | `bind`, `unbind`, `unbindall`, `bindlist` |
| Input (`engine/input/impl/input.impl.jac`) | `+`/`-` `forward`, `back`, `moveleft`, `moveright`, `left`, `right`, `lookup`, `lookdown`, `moveup`, `movedown`, `speed`, `strafe`, `attack`, `jump`, `use`, `klook`, `mlook`, `showscores`, `scores`, `button2`; `impulse`, `weapon`, `weapnext`, `weapprev`, `invuse`, `invnext`, `invprev`, `inven`, `help`, `centerview` |
| Host (`engine/core/app.jac` `HOST_COMMANDS`) | `map`, `quit`, `god`, `noclip`, `give`, `kill`, `use`, `cmd`, `exec`, `writeconfig`, `save`, `load`, `screenshot`, `vid_restart`, `toggleconsole`, `togglemenu` |

`impulse` 1-8, 10 and 12 choose and cycle weapons; 9 and 255 are Quake's
weapon and quad cheats. `give` takes `all`, `health`, `weapons`, `ammo`,
`armor`, a weapon, ammo or item name, and Q1's single-letter forms. `exec`
reads a file from the game directory, else from its archives. `writeconfig`
writes the bindings and archived cvars to a `.cfg` in the game directory.
`screenshot` writes the next free `quakepassion####.png` in the working
directory.

### Cvars

| Owner | Cvars (other games' names) |
|---|---|
| Host | `skill` (`g_spSkill`), `qp_god`, `qp_flyspeed`, `qp_overlay` |
| Input | `sensitivity`, `m_pitch`, `m_yaw`, `m_forward`, `m_side`, `freelook` (`cl_freelook`), `lookstrafe`, `cl_forwardspeed`, `cl_backspeed`, `cl_sidespeed`, `cl_upspeed`, `cl_movespeedkey`, `cl_yawspeed`, `cl_pitchspeed`, `cl_anglespeedkey`, `cl_run` |
| Renderer | `fov` (`cg_fov`), `host_maxfps` (`cl_maxfps`, `com_maxfps`), `r_novis`, `vid_width` (`r_customwidth`), `vid_height` (`r_customheight`), `vid_fullscreen` (`r_fullscreen`), `vid_highdpi` |
| HUD | `crosshair` (`cg_drawCrosshair`) |
| Audio | `volume` (`s_volume`), `bgmvolume` (`s_musicvolume`) |
| Console | `scr_conspeed` (`con_conspeed`), `con_notifytime` |

## Key bindings as data

`engine/input/keys.jac`: a `Keyboard` node `HasKey` edges to `Key` nodes, one
per key number of the originals (`Key_KeynumToString` names: `MOUSE1`-`5`,
`MWHEELUP`/`MWHEELDOWN`, `KP_*`, `COMMAND`), each holding its binding.
`PollKeys` turns raylib's state into key events (`Sys_SendKeyEvents`); a
wheel notch is a press and release in one frame. A key's binding runs through
the command buffer; a `+command` binding sends its `-command` with the key
name on release, in every mode, so nothing stays held through the console or
menu. Alt+Enter toggles `vid_fullscreen` and runs `vid_restart`
(`CL_KeyEvent`); a click on a free cursor captures the mouse instead of
firing.

When a game is configured (`App.configure_game`), the buffer runs, in order:

1. The game's own `default.cfg` (a loose file in the game directory, else from
   the archives).
2. QuakePassion's layer from `games/controls.jac` `GAME_BINDING_LAYERS`: WASD
   and the mouse wheel for Q1 and Q2, F3 `toggle qp_overlay` and F4 `noclip`
   for all, F6/F9 quick save and load and F12 `screenshot` for Q3. A game
   without a `default.cfg` (Passion, or missing archives) gets the complete
   `FALLBACK_BINDINGS` instead.
3. The user's settings file, then that game's bindings file.

Command-line arguments starting with `+` then run as console lines
(`Cmd_StuffCmds_f`, `engine/console/shell.jac` `command_line_text`):
`./qp +map e1m2 +god` runs `map e1m2`, then `god`.

## Files

| File | Holds | Written |
|---|---|---|
| `~/.quakepassion-settings.txt` | `seta` lines for every archived cvar, after a `// QUAKEPASSION SETTINGS 4` header (versions 1-3, rows of numbers, are read as the cvars that replaced them) | On each settings change and at exit |
| `~/.quakepassion-<game>-bindings.cfg` | That game's `bind` lines (`Key_WriteBindings`) | On a Controls change, and at exit when a `bind` changed them |
| `~/.quakepassion-save.txt`, `~/.quakepassion-save-<name>.txt` | Quick and named saves (`save`, `load`) | On save |
| `~/.quakepassion-arena.txt`, `~/.quakepassion-awards.txt` | Q3 ladder progress and awards | As the ladder advances |

`QP_CONFIG_DIR` moves the settings and bindings files only; saves and the Q3
progress files always use `HOME` (`App.save_file`, `games/arenas.jac`).
`QP_SMOKE=1` runs skip the user's bindings and do not save settings at exit.

## Environment and command line

`main.jac` reads: `QP_GAME` (`q1` default, `q2`, `q3`, `passion`), `QP_MAP`,
`QP_ASSETS`, `QP_SEED` (Passion), `QP_GRAYBOX=1` (the development arena),
`QP_WALK=0` (start flying), `QP_SMOKE=1` and `QP_CAPTURE=<frame>:<file.png>`
(see [validation tooling](validation-tooling-status.md)), `QP_CONFIG_DIR`, and
`+command` arguments. Starting Quake II without `QP_MAP` plays `ntro.cin`
before base1, as its `newgame` does.

## Window

The window is resizable (`vid_width`/`vid_height` follow a manual resize).
`vid_fullscreen` (the settings menu's Fullscreen row, or Alt+Enter) makes it
a window without decorations covering its monitor at the desktop resolution,
switching no video mode; turning it off restores the windowed size, centred.
Exclusive fullscreen is not used: on macOS, GLFW's monitor modes omit the
desktop's HiDPI mode, so putting the window on the monitor switched the
display to the nearest other mode (1920x1200 on a 16" MacBook Pro). The
macOS menu bar stays over the top strip of the screen; the system's own
fullscreen (Ctrl+Cmd+F) hides it. `vid_restart` applies the video cvars. `vid_highdpi` renders at the display's full pixel density
from the next start. The field of view is the horizontal angle of a 4:3 view
(`SCR_CalcRefdef`), so wider windows see more to the sides.

## Cinematics

Q2 `.cin` films (`engine/core/cinematic.jac`, `engine/formats/q2/cin.jac`)
skip when any key is pressed after the first second, once every key has been
let go since the film began. The menu blanks the picture and the console
drops over it (`SCR_DrawCinematic`).

## Validation

- `tests/console_shell_tests.jac`: splitting command lines, cvar kinds and
  bounds, set/show/toggle/reset and lists, cvars set before registration,
  aliases and `wait` in buffer order, `+command` arguments.
- `tests/console_bindings_tests.jac`: key names, `default.cfg` plus the layer
  and console rebinding, button release, `CL_BaseMove`, one-shot commands,
  console editing and completion, row wrapping, the controls menu rows, and
  the settings and bindings files as scripts.
- `tests/level_menu_tests.jac`: map discovery and `is_q1_level`.
- `tests/cinematic_tests.jac`: `.cin` decoding and timing, and music tracks.
- `jac run scripts/validate_menu.jac` builds `scripts/menu_smoke.jac` and runs
  it with a disposable `HOME` (so it never touches your files). Through raylib
  input events it checks the console (`god`, a cvar, toggling), every
  settings row, the saved settings and bindings files, a window resize,
  binding and clearing a key in Controls and resetting them, the level list's
  scrolling and selection, loading Q1 start, Q2 base1 and Q3 q3dm1 with each
  game's bindings, a failed load that keeps the level, and Quit. Screenshots
  and the log go to `.jac/screenshots/menu/`.

## Limitations

- The Q2 inventory's hotkey column is a fixed table of Q2's default binds, not
  the current bindings.
- Loading a level and scanning archives stall the frame.
