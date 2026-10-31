# Optional 3D model overrides

Pokémon Journey ships **no third-party models**. Every Pokémon and trainer you see in the
game is generated procedurally at runtime by:

- `scripts/models/pokemon_model.gd` — multi-mesh sculpts (bodies, wings, shells, tails, horns,
  eyes, accents) with idle, attack, hit, faint and victory animation hooks.
- `scripts/models/trainer_model.gd` — stylised human trainers with hair, outfits, caps and bags.

You can replace any of them with your own `.glb` file. The game detects the file at load time
and uses it instead of the procedural model. **No code changes are required.**

---

## File names

Drop files directly into this folder (`res://assets/models/`):

| File | Replaces |
| --- | --- |
| `charizard.glb` | Charizard |
| `bulbasaur.glb` | Bulbasaur |
| `gengar.glb` | Gengar |
| `pikachu.glb` | Pikachu |
| `squirtle.glb` | Squirtle |
| `trainer_kai.glb` | Trainer Kai |
| `trainer_mira.glb` | Trainer Mira |
| `trainer_rowan.glb` | Trainer Rowan |
| `trainer_sora.glb` | Trainer Sora |
| `trainer_nova.glb` | Trainer Nova |
| `trainer_rex.glb` | Trainer Rex |

Names are lowercase and must match the IDs in `data/pokemon/*.tres` and `data/trainers.json`.
`.gltf` (with a separate `.bin`) also works if Godot imports it, but `.glb` is the simplest
single-file option.

After adding a file, let Godot import it (open the project in the editor once, or run
`godot --headless --editor --path . --quit`) before running the game.

---

## Scale and orientation

- **Units:** 1 Godot unit = 1 metre. A human trainer is about 1.7 m tall.
- **Recommended model heights**

  | Model | Height (units) |
  | --- | --- |
  | Charizard | ~2.2 |
  | Bulbasaur | ~0.8 |
  | Gengar | ~1.7 |
  | Pikachu | ~0.6 |
  | Squirtle | ~0.7 |
  | Trainer | ~1.7 |

- **Origin:** the model's origin should be at the **centre of its feet**, on the ground plane
  (y = 0). Models are placed directly on the floor; a model built around its centre will sink.
- **Facing direction:** the game expects models to face **+Z** (Godot's forward). Characters
  are rotated to look at their target at runtime, so a model facing +X or -X will appear to
  strafe sideways.
- **Per-species scaling:** each `PokemonData` resource has a `model_scale` field. Adjust it in
  `data/pokemon/<id>.tres` if your replacement needs a global size tweak. The value multiplies
  the model's scale, so leave it at `1.0` for correctly sized assets.

---

## Animation

The game animates the root node of the model, not individual bones:

- idle bobbing/sway (procedural, applied to the model root)
- attack lunge
- hit flash and recoil
- faint collapse
- victory hop

If your `.glb` includes its own `AnimationPlayer`, it will **not** be driven by the battle
system. That is intentional: the procedural animation must work identically for every model.
Baked animations will simply sit at their first frame. Keep the model in a neutral T/A-pose
and let the root-node animation provide the motion, or accept a static pose.

---

## Fallback behaviour

- If a `.glb` is missing, the procedural model is used. Nothing breaks.
- If a `.glb` exists but fails to import or instantiate, the game logs a warning
  (`Could not load external model: <path>`) and falls back to the procedural sculpt.
- A missing or broken override never blocks a battle, a preview, or a scene load.

You can confirm which assets are active in **Settings → Save & asset diagnostics**, which
prints the species/move/trainer counts and any asset warnings.

---

## Licensing — read this before adding files

This project is a non-commercial fan tribute. Only add models you have the right to use:

- **Allowed:** models you created, commissioned, or downloaded under a licence that permits
  redistribution (CC0, CC-BY, or a paid licence that allows it). Credit the author in your
  own build.
- **Not allowed:** ripped or extracted models from official Pokémon games, ROM dumps, or
  fan models whose authors did not grant redistribution rights. Do not commit or distribute
  those files, and do not ship a build containing them.

Pokémon and all related names are trademarks of Nintendo / Creatures Inc. / GAME FREAK.
This project is not affiliated with or endorsed by them.
