# Developer tools

Optional headless checks and data generators. **They are not part of the shipped game** and
are never loaded during normal play. You can delete the folder without affecting the build.

All commands assume Godot 4.7+ is on your `PATH` and are run from the project root:

```powershell
cd "C:\pokemon  journey"
godot --version
```

If you do not have Godot on `PATH`, substitute the full path to the executable.

---

## ⚠️ These tests write to your real save

The flow, gameplay and Rocket tests start a scene through `GameState`, which saves to the
normal `user://` slot. That means running them can overwrite your journey.

**Back up first:**

```powershell
$save = "$env:APPDATA\Godot\app_userdata\Pokémon Journey"
Copy-Item "$save\pokemon_journey_save.json"        "$env:TEMP\pj_save.json" -Force
Copy-Item "$save\pokemon_journey_save.backup.json" "$env:TEMP\pj_backup.json" -Force
```

**Restore afterwards:**

```powershell
$save = "$env:APPDATA\Godot\app_userdata\Pokémon Journey"
Copy-Item "$env:TEMP\pj_save.json"        "$save\pokemon_journey_save.json" -Force
Copy-Item "$env:TEMP\pj_backup.json"      "$save\pokemon_journey_save.backup.json" -Force
```

`smoke_test.gd`, `balance_test.gd` and `damage_test.gd` only touch in-memory state and do not
call `save_game()`, so they are safe.

---

## Scripts

### `build_data.gd` — regenerate resources

Rebuilds all 20 move resources and the 5 species resources from the definitions in the
script.

```powershell
godot --headless --path . --script res://tools/build_data.gd
```

Writes to `data/moves/*.tres` and `data/pokemon/*.tres`. Run it after changing move or species
stats. It does not touch trainers, opponents or the Rocket roster (those are hand-edited JSON).

### `smoke_test.gd` — scene instantiation

Loads and instantiates every core scene, waits 60 frames each, and reports any scene that
fails to load, errors at runtime, or frees itself unexpectedly.

```powershell
godot --headless --path . --script res://tools/smoke_test.gd
```

Exit code `0` on success. Use this first after editing scripts or scenes; it catches parse
errors that would otherwise show up as a blank/blue screen in the real game.

### `gameplay_test.gd` — battle loop

Instantiates the battle scene, waits for the intro, plays turns until the battle resolves, and
verifies the result overlay and summary. Also checks the Rocket cinematic preserves
`pending_battle` and that the Rocket battle keeps its shadow opponent.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tools/gameplay_test.gd
```

`--fixed-fps 60` makes the timing-based `await` animations advance deterministically and fast.

### `damage_test.gd` — damage and HP display regression

Plays one controlled turn, checks that both Pokémon lose HP, and confirms each health bar and
HP label match the battle state. It uses in-memory data and does not finish or save the battle.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tools/damage_test.gd
```

### `flow_test.gd` — full journey

Walks the real scene router end to end:

```
loading screen -> main menu -> trainer select -> starter select -> playground
-> walking -> battle -> result -> playground -> arena -> walking
-> collection -> settings -> arenas screen
```

Verifies the player does not fall through either world's floor and can move, that
`regular_matches_completed` increments, and that each sub-screen opens.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tools/flow_test.gd
```

### `rocket_test.gd` — Team Rocket event

Seeds `rocket_pending`, opens the arena, waits for the automatic cinematic, skips the dialogue,
hands off to the battle, forces a win, and checks that the event is consumed exactly once and a
badge is awarded.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tools/rocket_test.gd
```

### `interaction_test.gd` — every world interaction

Uses `Interactable.interact(player)` exactly like the player does and exercises every callback
in both worlds: petting your partner, the training sign, the rest tent, the Poké PC, both
gates, the arena announcer, and an NPC challenge in each location. It verifies the correct
opponent starts each battle and that non-battle interactions never queue one.

Run this after touching `Interactable` or any `_spawn_npc` / `_spawn_interactables` code.

```powershell
godot --headless --fixed-fps 60 --path . --script res://tools/interaction_test.gd
```

### `exhibition_test.gd` — exhibition auto-battle

Verifies the AI-vs-AI exhibition flow: both fighters are chosen, turns play out on screen logic,
HP changes, and the battle completes with a result. No XP or progression is awarded.

```powershell
godot --headless --path . --script res://tools/exhibition_test.gd
```

### `balance_test.gd` — AI-vs-AI win rates

Simulates 80 seeded battles per matchup for all five starters against the regular opponents at
two level offsets. Prints win percentages so difficulty can be tuned.

```powershell
godot --headless --path . --script res://tools/balance_test.gd
```

### `screenshot_test.gd` — rendered screenshots

Requires a **real window** (not `--headless`). Captures PNGs of the menu, playground, arena,
battle and Rocket cinematic into
`%TEMP%\opencode\shots\`, then quits.

```powershell
godot --path . --fixed-fps 60 --resolution 1280x720 --script res://tools/screenshot_test.gd
```

### `arena_probe.gd` — arena diagnostics

Renders the arena from the player camera and from a free camera, and prints camera position,
player height and every light. Useful when the arena looks too dark or the player appears to
fall.

```powershell
godot --path . --fixed-fps 60 --resolution 1280x720 --script res://tools/arena_probe.gd
```

---

## Notes and gotchas

- **`--script` mode and autoloads:** headless `--script` runs do not expose autoloads as global
  identifiers at compile time. The tests fetch them with
  `root.get_node_or_null("GameState")` instead.
- **Scene transitions:** `SceneRouter.goto()` swaps `current_scene` mid-fade and returns early
  if a transition is already running. Tests wait for `SceneRouter.transitioning == false`
  before the next navigation.
- **Battle busy flag:** a finished battle keeps `_busy = true`, so tests wait on `_ended` (or
  the result overlay becoming visible) rather than only on `_busy`.
- **Fresh class cache:** after adding a new `class_name` or a new scene, run
  `godot --headless --editor --path . --quit` once so Godot registers the class before any
  autoload tries to parse a script that references it.
- **Leaked instance warnings** at exit (`ObjectDB instances were leaked`) are harmless in
  headless script runs; they come from `RefCounted` objects still held by the test tree when
  `quit()` fires.

---

## Adding a test

Start from `smoke_test.gd`: it is the smallest complete example. Conventions used by the other
scripts:

```gdscript
extends SceneTree

func _initialize() -> void:
    call_deferred("_run")          # autoloads exist by the time _run executes

func _run() -> void:
    await process_frame
    var gs = root.get_node_or_null("GameState")
    # ... exercise the game ...
    quit(0)                        # 0 = pass, 1 = fail
```

Print a single `NAME FAIL: reason` line per failure and a final `NAME DONE: N failure(s)`
summary, so the output stays greppable.
