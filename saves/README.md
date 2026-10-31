# Save data

Pokémon Journey stores the entire journey in a single JSON file, written through Godot's
`user://` virtual filesystem.

---

## Location

`user://` maps to a per-user application data folder. On Windows:

```
%APPDATA%\Godot\app_userdata\Pokémon Journey\
├── pokemon_journey_save.json          # live save
├── pokemon_journey_save.backup.json   # previous save, written before each overwrite
└── logs\godot.log                     # engine log
```

On Linux: `~/.local/share/godot/app_userdata/Pokémon Journey/`
On macOS: `~/Library/Application Support/Godot/app_userdata/Pokémon Journey/`

The exact folder can be opened from **Settings → Open save folder**.

---

## When it saves

The game saves automatically after meaningful events:

- choosing a trainer and a starter
- finishing a battle (regular or Team Rocket)
- unlocking a partner or earning a badge
- changing the active partner
- travelling between locations
- changing a setting (music, SFX, camera sensitivity, fullscreen)

There is no manual "save" button and no way to lose progress by closing the window mid-menu.

---

## Schema (version 2)

```jsonc
{
  "version": 2,
  "trainer_id": "kai",                 // one of the ids in data/trainers.json
  "trainer_name": "Ash",               // player-entered name, max 18 chars
  "starter_id": "pikachu",             // the partner chosen at the start
  "active_pokemon": "pikachu",         // partner currently used in battle
  "unlocked": ["pikachu", "bulbasaur"],
  "xp": {                              // per-species XP, independent of level
    "charizard": 0,
    "bulbasaur": 120,
    "gengar": 0,
    "pikachu": 340,
    "squirtle": 0
  },

  "regular_matches_completed": 3,      // wins + losses, drives Rocket timing
  "regular_wins": 2,                   // drives partner unlocks
  "battles_won": 2,
  "battles_lost": 1,

  "rocket_pending": false,             // a Rocket event is queued for the arena
  "rocket_events_completed": 1,        // prevents the same event retriggering
  "rocket_wins": 1,
  "rocket_badges": 1,

  "current_location": "playground",    // "playground" or "arena"

  "settings": {
    "music": 0.62,
    "sfx": 0.8,
    "fullscreen": false,
    "camera_sensitivity": 0.0024
  },

  "tutorial_seen": false,
  "playground_tip_seen": false,
  "created_at": "2026-01-01T12:00:00",
  "updated_at": "2026-01-02T18:30:00"
}
```

Fields are validated and clamped on load. Unknown or missing keys fall back to defaults, so an
older save keeps working after an update.

---

## Backup and restore

A backup is written automatically before every overwrite. To restore it:

1. Close the game.
2. Open the save folder (Settings → Open save folder, or the path above).
3. Rename `pokemon_journey_save.json` to `pokemon_journey_save.broken.json`.
4. Copy `pokemon_journey_save.backup.json` and rename the copy to
   `pokemon_journey_save.json`.
5. Start the game and choose **Continue**.

If the main file is corrupt or unreadable, the game already falls back to the backup on its
own and logs a warning. It only starts a fresh journey when **both** files are unreadable.

### Manual backup

Copy both JSON files somewhere safe. Restoring is the same process in reverse. Keep the two
files together so the backup stays one save behind the live file.

---

## Reset

**Settings → Reset Journey…** asks for confirmation, then deletes both the live save and the
backup and returns to the main menu with a fresh profile.

To reset by hand, close the game and delete both JSON files. The next launch creates a new
profile on first save.

---

## Editing a save by hand

It is plain JSON, so you can edit it, but keep these rules in mind:

- `regular_matches_completed` must stay `>= regular_wins`; progression assumes it.
- Unlock checks run on every battle result, so manually adding an id to `unlocked` is enough
  to use it immediately, but the next unlock pass may re-add ids that qualify anyway.
- `rocket_pending` should be `true` only when you want the arena cinematic to fire on the next
  visit. Set it to `false` to skip a queued event.
- `rocket_events_completed` is the guard against duplicate events. Lowering it can replay
  events; raising it skips them.
- XP values are cumulative totals, not "XP toward next level". Levels are derived from the
  total by `GameState.level_for_xp()`.
- Keep `version` at `2`.

Back up the file before editing. Malformed JSON makes the game load the backup instead.
