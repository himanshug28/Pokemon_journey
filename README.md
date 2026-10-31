# Pokémon Journey

A complete 3D Pokémon-inspired battle adventure built with **Godot 4.7** and **GDScript**.
Explore a stadium playground in third person, challenge trainers, win turn-based battles,
unlock all five partners, and survive Team Rocket's hostile takeover of the Battle Arena.

> This is a fan-made project with original procedural artwork, original chiptune music and
> open-licensed fonts. It is not affiliated with Nintendo, Creatures Inc. or GAME FREAK, and it
> does not ship any official Pokémon assets. See **Assets & licensing** below.

---

## Quick start

1. Install **Godot 4.7 or newer** (standard build, no C# required).
2. Open `project.godot` in the editor.
3. Press **F5** (or run `godot --path .` from this folder).
4. The loading screen preloads scenes and music, then opens the main menu automatically.

The project uses the **GL Compatibility** renderer so it runs on integrated GPUs and older
hardware. No external plugins or downloaded content are required.

---

## Controls

| Context | Input | Action |
| --- | --- | --- |
| World | `W` `A` `S` `D` | Move |
| World | Mouse | Orbit the third-person camera |
| World | `Shift` | Sprint |
| World | `Space` | Jump |
| World | `E` | Interact / challenge / travel / pet your partner |
| World | `Esc` | Pause, travel, collection, settings, main menu |
| Battle | `1` `2` `3` `4` | Choose a move |
| Battle | `Esc` | Forfeit (records a loss) |
| Menus | Mouse / arrows / `Enter` | Navigate |
| Menus | `Esc` | Back |

---

## What is in the game

### Loading screen
Cinematic title screen with a spinning Poké Ball, particle field, partner silhouettes,
a live progress bar, rotating tips and an original menu theme. It preloads every core scene
and all seven music tracks before handing off to the menu.

### Main menu
New journey, continue, battle arenas, partner collection, settings and quit. Continue is
enabled only when a valid save exists.

### Trainer & starter selection
Six original trainer looks with 3D previews, a custom trainer name, then a separate partner
selection screen for **Charizard, Bulbasaur, Gengar, Pikachu and Squirtle** with stats, types,
moves and 3D previews.

### Stadium Playground
A bright outdoor training park in front of the stadium:
- Free third-person movement with a spring-arm camera, sprint and jump.
- A partner Pokémon that follows you and can be petted.
- Four NPC challengers with distinct teams, dialogue and difficulty.
- A gate to the Battle Arena, a Poké PC (collection), a rest tent (heal message), and a
  training-tips sign.
- A persistent HUD showing location, active partner, level/XP, Rocket status and prompts.

### Battle Arena
A floodlit night stadium with tiered stands, a crowd, a jumbotron, side scoreboards,
four arena challengers, an announcer, a travel gate and the Team Rocket centre stage.

### Exhibition Match
From the main menu you can pick two of the five Pokémon and watch them fight each other in
an AI-vs-AI auto-battle on the same 3D battle stage. No XP, unlocks or progression are awarded
for exhibition matches; use Rematch or Change Fighters from the result screen.

### Turn-based battles
- Real HP, Attack, Defense, Speed, level scaling and PP.
- Four moves per Pokémon, each with power, accuracy, type, effects and priority.
- Type effectiveness, STAB, critical hits, damage variance, status conditions
  (burn, poison, paralysis), stat stages and healing moves.
- A deterministic event stream drives attack lunges, hit flashes, particles, camera shakes,
  HP-bar animation, faint animations and victory poses.
- XP, level-ups, unlock checks and a result screen with rewards and badges.

### Progression and unlocks
- Every completed regular match counts toward progression (wins and losses).
- Wins unlock partners:
  - **Bulbasaur** — 1 regular win
  - **Squirtle** — 2 regular wins
  - **Charizard** — 3 regular wins
  - **Gengar** — 4 regular wins or 1 Team Rocket win
  - **Pikachu** — 5 regular wins or 2 Team Rocket wins
- Your chosen starter is always unlocked.
- The Collection screen shows locked partners as silhouettes, live 3D previews, stats, moves,
  XP and lets you set any unlocked partner as the active one.

### Team Rocket events
After every **two completed regular matches**, a Rocket event becomes pending. The next time
you enter the Battle Arena:
1. The lights dim and the arena announces the siege.
2. A 2D cinematic plays with a rocket backdrop, purple particles, a giant R, a shadow Pokémon
   preview and sequential villain dialogue (skippable).
3. The battle starts against a purple-aura **Shadow** variant of a Rocket Pokémon.
4. Winning awards a Rocket badge and counts toward Gengar/Pikachu unlocks. The event is
   consumed on completion (win or loss) so it never retriggers incorrectly.

### Save data
Everything is persisted to JSON:
- Trainer identity and chosen starter
- Active partner and every partner's XP
- Unlocks, wins/losses, completed matches, badges
- Rocket pending/completed/wins state
- Current location
- Audio, camera and display settings

Save location on Windows:

```
%APPDATA%\Godot\app_userdata\Pokémon Journey\pokemon_journey_save.json
%APPDATA%\Godot\app_userdata\Pokémon Journey\pokemon_journey_save.backup.json
```

A backup is written before each save. If the main file is corrupt, the game loads the backup.
Settings → **Reset Journey…** permanently clears both files. See `saves/README.md`.

---

## Project layout

```
assets/            fonts, optional models/textures, default environment
data/              generated .tres resources + trainer/opponent/Rocket JSON
scenes/            UI, world, player and battle scenes (.tscn)
scripts/
  autoload/        GameState, UIKit, AudioManager, AssetLibrary, SceneRouter
  battle/          BattleSim, BattleCombatant, battle scene, Rocket cinematic
  data/            MoveData, PokemonData, TypeChart
  models/          procedural Pokémon and trainer models
  player/          third-person controller
  ui/              loading, menu, selection, collection, settings, arenas, widgets
  world/           playground, arena, HUD, interactables, world builder
shaders/           UI shader
saves/             save documentation
tools/             data generator + optional headless test scripts
```

---

## Assets & licensing

All shipped art and audio are original and generated at runtime or in code:

- **Pokémon models** — multi-mesh procedural sculpts (bodies, wings, shells, tails, horns,
  eyes, accents, particles), not placeholder cubes.
- **Trainers** — procedural stylised humans with hair, outfits, caps, bags and glasses.
- **Worlds** — procedural stadium geometry, stands, crowds, screens, props and lighting.
- **UI** — runtime theme, gradients, particles, Poké Ball icon and type badges.
- **Audio** — original chiptune music and synthesized SFX/cries generated by `AudioManager`.
- **Fonts** — Lilita One and Nunito, both under the SIL Open Font License. License texts are
  included in `assets/fonts/`.

### Optional GLB overrides

You can drop higher-detail models into `assets/models/` and the game will use them
automatically. See `assets/models/README.md` for names, scale and orientation. Only add
assets you own or that are licensed for your use. Do **not** distribute ripped official
Pokémon models.

---

## Developer tools

The `tools/` folder contains optional headless checks. They are not part of the shipped game.

```powershell
# Regenerate move/species resources from tools/build_data.gd
godot --headless --path . --script res://tools/build_data.gd

# Instantiate every core scene and report runtime errors
godot --headless --path . --script res://tools/smoke_test.gd

# Exercise a full battle (intro -> turns -> result overlay)
godot --headless --fixed-fps 60 --path . --script res://tools/gameplay_test.gd

# Full journey: loading -> menu -> trainer -> starter -> playground -> battle ->
# arena -> collection/settings/arenas
godot --headless --fixed-fps 60 --path . --script res://tools/flow_test.gd

# Team Rocket cinematic -> shadow battle -> reward/consumption
godot --headless --fixed-fps 60 --path . --script res://tools/rocket_test.gd
```

These tests write to the normal save slot. Back up your save first, or run them on a fresh
profile. See `tools/README.md`.

---

## Troubleshooting

**A blank/blue screen after pressing Play** — this was caused by GDScript parse errors in the
world scripts, which prevented the playground and arena from loading. The errors are fixed and
the scenes are covered by the smoke/flow tests above. If you see a blank screen after editing
scripts, run:

```powershell
godot --headless --editor --path . --quit
```

to refresh Godot's class cache, then run the game again.

**Nothing renders / very low FPS** — the project targets GL Compatibility. Update your GPU
drivers or switch the renderer in Project Settings → Rendering → Renderer.

**No audio** — the soundtrack is synthesized at load time. The first launch may take a second
longer while tracks are prepared. Check Settings → Music/SFX.

**Save looks wrong** — close the game, then copy
`pokemon_journey_save.backup.json` over `pokemon_journey_save.json` in the save folder above.
Or use Settings → Reset Journey.

Logs are written to:

```
%APPDATA%\Godot\app_userdata\Pokémon Journey\logs\godot.log
```

---

## Credits

- Engine: [Godot Engine](https://godotengine.org) 4.7 (MIT).
- Fonts: Lilita One by Juan Pablo del Peral; Nunito by Vernon Adams, Cyreal and Jacques Le
  Bailly (SIL OFL 1.1).
- Design, code, procedural models, world art, UI and chiptune audio: original work for this
  project.

Pokémon and all related names are trademarks of Nintendo / Creatures Inc. / GAME FREAK.
This project is a non-commercial fan tribute and is not endorsed by them.
